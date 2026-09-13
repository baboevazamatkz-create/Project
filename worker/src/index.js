// Разбор чеков и банковских скриншотов.
//
// Приложение присылает сюда снимок, воркер спрашивает у модели, что на нём
// изображено, и возвращает список операций. Ключ Anthropic хранится
// секретом воркера: положить его в клиент нельзя -- и веб-сборку, и APK
// можно разобрать и достать оттуда что угодно.
//
// Единственный пропуск -- токен Firebase того же проекта, что и у
// приложения. Проверяется подпись, издатель, адресат и срок.

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VERSION = '2023-06-01';
const JWK_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

// Снимок после уменьшения на стороне приложения весит сотни килобайт;
// четыре мегабайта -- это заведомо выше потолка и заведомо ниже того,
// что модель принимает.
const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const MAX_IMAGES = 12;
const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp'];

// Совпадает с ExpenseCategory в приложении. Всё, что модель вернёт
// помимо этого списка, превращается в other.
const CATEGORIES = [
  'food',
  'transport',
  'housing',
  'entertainment',
  'health',
  'shopping',
  'other',
];
const CURRENCIES = ['rub', 'kzt', 'usd'];

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS },
  });
}

// --- проверка токена Firebase ------------------------------------------

let jwkCache = { at: 0, keys: null };

async function googleKeys() {
  // Ключи Google меняются раз в несколько дней; час кэша убирает лишний
  // запрос перед каждым разбором, не рискуя застрять на отозванном ключе.
  if (jwkCache.keys && Date.now() - jwkCache.at < 3600_000) return jwkCache.keys;
  const res = await fetch(JWK_URL);
  if (!res.ok) throw new HttpError(503, 'Не удалось получить ключи Google');
  const body = await res.json();
  jwkCache = { at: Date.now(), keys: body.keys || [] };
  return jwkCache.keys;
}

function base64UrlToBytes(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(padded.padEnd(Math.ceil(padded.length / 4) * 4, '='));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function decodeSegment(value) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(value)));
}

async function verifyIdToken(token, projectId) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new HttpError(401, 'Некорректный токен');

  let header;
  let payload;
  try {
    header = decodeSegment(parts[0]);
    payload = decodeSegment(parts[1]);
  } catch {
    throw new HttpError(401, 'Некорректный токен');
  }

  if (header.alg !== 'RS256') throw new HttpError(401, 'Некорректный токен');

  const jwk = (await googleKeys()).find((k) => k.kid === header.kid);
  if (!jwk) throw new HttpError(401, 'Токен подписан неизвестным ключом');

  const key = await crypto.subtle.importKey(
    'jwk',
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlToBytes(parts[2]),
    signed,
  );
  if (!valid) throw new HttpError(401, 'Подпись токена не сходится');

  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || payload.exp < now) {
    throw new HttpError(401, 'Срок действия токена истёк');
  }
  if (payload.aud !== projectId) throw new HttpError(401, 'Чужой проект');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new HttpError(401, 'Чужой проект');
  }
  if (!payload.sub) throw new HttpError(401, 'Токен без пользователя');
  return payload.sub;
}

// --- суточный предел ----------------------------------------------------

async function useQuota(env, uid) {
  if (!env.SCAN_QUOTA) return;
  const limit = Number(env.DAILY_LIMIT || '60');
  const key = `${uid}:${new Date().toISOString().slice(0, 10)}`;
  const used = Number((await env.SCAN_QUOTA.get(key)) || '0');
  if (used >= limit) {
    throw new HttpError(429, 'На сегодня разборов больше нет, попробуйте завтра');
  }
  // Срок жизни с запасом: счётчик всё равно привязан к дате в ключе.
  await env.SCAN_QUOTA.put(key, String(used + 1), { expirationTtl: 172800 });
}

// --- запрос к модели ----------------------------------------------------

const TOOL = {
  name: 'record_transactions',
  description:
    'Записать все денежные операции, которые видны на снимке. '
    + 'Если операций нет, вернуть пустой список.',
  input_schema: {
    type: 'object',
    properties: {
      document: {
        type: 'string',
        enum: ['receipt', 'statement', 'other'],
        description:
          'receipt -- кассовый чек или счёт; statement -- выписка, история '
          + 'операций или скриншот банковского приложения; other -- всё прочее.',
      },
      transactions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            type: {
              type: 'string',
              enum: ['expense', 'income'],
              description:
                'expense -- деньги ушли, income -- пришли. Ориентируйтесь на '
                + 'знак суммы, цвет строки и подписи вроде «пополнение», '
                + '«перевод от», «зачисление».',
            },
            amount: {
              type: 'number',
              description: 'Положительное число, без знака и без пробелов.',
            },
            currency: {
              type: 'string',
              enum: CURRENCIES,
              description:
                'Валюта операции, если её видно по символу или коду. '
                + 'Если не видно -- не указывать.',
            },
            date: {
              type: 'string',
              description:
                'Дата операции в формате ГГГГ-ММ-ДД. «Сегодня» и «вчера» '
                + 'считать от переданной текущей даты. Если даты нет -- '
                + 'подставить текущую.',
            },
            note: {
              type: 'string',
              description:
                'Короткое название: магазин, получатель или назначение. '
                + 'Не более 60 символов, без суммы и даты.',
            },
            category: {
              type: 'string',
              enum: CATEGORIES,
              description:
                'food -- продукты, кафе, доставка еды; transport -- проезд, '
                + 'такси, топливо; housing -- аренда, коммунальные, связь и '
                + 'интернет; entertainment -- кино, подписки, бары, поездки; '
                + 'health -- аптека, врачи, спорт; shopping -- одежда, '
                + 'техника, товары для дома; other -- всё остальное и любые '
                + 'поступления.',
            },
            confidence: {
              type: 'number',
              description:
                'Насколько уверенно прочитана строка, от 0 до 1. Ставьте '
                + 'ниже 0.6, если сумма или дата видны плохо.',
            },
          },
          required: ['type', 'amount', 'date', 'note', 'category'],
        },
      },
    },
    required: ['document', 'transactions'],
  },
};

function systemPrompt(today, currency) {
  return [
    'Вы разбираете снимки, которые человек делает для учёта личных денег: ',
    'кассовые чеки, счета, скриншоты банковских приложений и выписок.',
    '',
    `Сегодня ${today}. Валюта бюджета по умолчанию: ${currency}.`,
    '',
    'Снимков может быть несколько. Это либо разные документы, либо, чаще, ',
    'последовательные куски одного длинного скриншота, идущие сверху вниз ',
    'и НАМЕРЕННО перекрывающиеся: несколько строк в конце одного куска ',
    'повторяются в начале следующего. Такую повторённую строку запишите ',
    'ОДИН раз.',
    '',
    'Чек:',
    '- Одна операция на весь чек -- итоговая сумма, а не отдельные товары. ',
    '  Итог -- это «Итого», «К оплате», «Всего».',
    '',
    'Выписка или история операций (обычно таблица: дата, сумма, тип ',
    'операции, описание):',
    '- Каждая строка -- отдельная операция, сверху вниз, в том же порядке.',
    '- Направление задаёт ЗНАК суммы, а не слово в колонке типа. Минус -- ',
    '  расход, плюс -- доход. Строка «Покупка + 7 605,00» -- это возврат, ',
    '  то есть доход.',
    '- Даты вида 08.09.26 -- это ДД.ММ.ГГ, то есть 2026-09-08.',
    '- Продолжение строки снизу -- сумма в скобках в другой валюте, ',
    '  «Курсовая разница», часы или пометка «Сумма заблокирована» -- ',
    '  относится к строке НАД ним и отдельной операцией не является. ',
    '  Заблокированная операция уже произошла: записывайте её как обычную.',
    '- Две одинаковые строки подряд с одной датой, суммой и описанием -- ',
    '  это две разные операции. Запишите обе.',
    '- В описание берите название продавца или получателя как есть: ',
    '  «Magnum Cash&Carry», «YANDEX.GO», «Magomed K.».',
    '',
    'Не берите строки, которые операцией не являются: остаток и доступный ',
    'лимит по счёту, кэшбэк-баллы, итоги и обороты за период, заголовки ',
    'таблицы, реквизиты банка, отменённые и отклонённые платежи.',
    '',
    'Сумму всегда возвращайте положительным числом -- направление задаёт ',
    'поле type. Если операций на снимке нет вовсе, верните пустой список. ',
    'Ничего не выдумывайте: пишите только то, что действительно видно.',
  ].join('\n');
}

function clampTransactions(raw, today, fallbackCurrency) {
  const out = [];
  for (const item of Array.isArray(raw) ? raw : []) {
    // Absolute value rather than a rejection: a statement writes an
    // expense as "- 1 920,00", and a model that faithfully carries that
    // minus through would otherwise have every expense on the page
    // silently dropped. Direction lives in `type`, never in the sign.
    const amount = Math.abs(Number(item?.amount));
    if (!Number.isFinite(amount) || amount === 0) continue;

    const date =
      typeof item?.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(item.date)
        ? item.date
        : today;
    const confidence = Number(item?.confidence);

    out.push({
      type: item?.type === 'income' ? 'income' : 'expense',
      amount: Math.round(amount * 100) / 100,
      currency: CURRENCIES.includes(item?.currency)
        ? item.currency
        : fallbackCurrency,
      date,
      note: String(item?.note ?? '').slice(0, 60),
      category: CATEGORIES.includes(item?.category) ? item.category : 'other',
      confidence: Number.isFinite(confidence)
        ? Math.min(1, Math.max(0, confidence))
        : 1,
    });
    if (out.length >= 100) break;
  }
  return out;
}

async function askModel(env, images, today, currency) {
  const content = images.map((image) => ({
    type: 'image',
    source: { type: 'base64', media_type: image.mime, data: image.data },
  }));
  content.push({
    type: 'text',
    text:
      'Разберите снимок и вызовите record_transactions со всеми операциями, '
      + 'которые на нём видны.',
  });

  const res = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': env.ANTHROPIC_API_KEY,
      'anthropic-version': ANTHROPIC_VERSION,
    },
    body: JSON.stringify({
      model: env.MODEL || 'claude-haiku-4-5-20251001',
      max_tokens: 8192,
      system: systemPrompt(today, currency),
      tools: [TOOL],
      tool_choice: { type: 'tool', name: TOOL.name },
      messages: [{ role: 'user', content }],
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    // Наружу уходит только то, что пользователю полезно знать.
    console.error('anthropic', res.status, detail.slice(0, 500));
    if (res.status === 429) {
      throw new HttpError(429, 'Сервис распознавания занят, попробуйте позже');
    }
    throw new HttpError(502, 'Не удалось разобрать снимок');
  }

  const body = await res.json();

  // A long statement can run past the answer budget. The tool call then
  // arrives half-written and its arguments come back empty, which used to
  // surface to the user as a cheerful "nothing found" -- the one answer
  // that is certainly wrong when the page is full of operations.
  if (body.stop_reason === 'max_tokens') {
    throw new HttpError(
      422,
      'На снимке слишком много операций. Снимите выписку по частям',
    );
  }

  const block = (body.content || []).find((b) => b.type === 'tool_use');
  if (!block) throw new HttpError(502, 'Не удалось разобрать снимок');
  return block.input || {};
}

// --- обработчик ---------------------------------------------------------

async function handleScan(request, env) {
  if (!env.ANTHROPIC_API_KEY) {
    throw new HttpError(500, 'Воркер не настроен: нет ключа ANTHROPIC_API_KEY');
  }

  const auth = request.headers.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) throw new HttpError(401, 'Нужен вход в приложение');
  const uid = await verifyIdToken(auth.slice(7).trim(), env.FIREBASE_PROJECT_ID);

  let payload;
  try {
    payload = await request.json();
  } catch {
    throw new HttpError(400, 'Тело запроса не разобрано');
  }

  // Одна картинка или несколько -- скриншот длинной истории телефон часто
  // отдаёт двумя кусками.
  const rawImages = Array.isArray(payload.images)
    ? payload.images
    : [{ data: payload.image, mime: payload.mime }];
  if (rawImages.length === 0 || rawImages.length > MAX_IMAGES) {
    throw new HttpError(400, 'Слишком много снимков за раз');
  }

  const images = rawImages.map((image) => {
    const data = typeof image?.data === 'string' ? image.data : '';
    const mime = ALLOWED_MIME.includes(image?.mime) ? image.mime : 'image/jpeg';
    if (!data) throw new HttpError(400, 'Пустой снимок');
    if (data.length > MAX_IMAGE_BYTES) throw new HttpError(413, 'Снимок слишком большой');
    return { data, mime };
  });

  const today = /^\d{4}-\d{2}-\d{2}$/.test(payload.today || '')
    ? payload.today
    : new Date().toISOString().slice(0, 10);
  const currency = CURRENCIES.includes(payload.currency) ? payload.currency : 'rub';

  await useQuota(env, uid);

  const result = await askModel(env, images, today, currency);
  return json({
    document: ['receipt', 'statement', 'other'].includes(result.document)
      ? result.document
      : 'other',
    transactions: clampTransactions(result.transactions, today, currency),
  });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (request.method === 'GET') {
      return new Response('solidus-scan ok\n', {
        headers: { 'Content-Type': 'text/plain; charset=utf-8', ...CORS },
      });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Метод не поддерживается' }, 405);
    }
    try {
      return await handleScan(request, env);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.message }, error.status);
      }
      console.error('unhandled', error && error.stack);
      return json({ error: 'Внутренняя ошибка' }, 500);
    }
  },
};

// Вынесено ради тестов на стороне приложения: форма ответа описана в
// test/scan_contract_test.dart и должна совпадать с clampTransactions.
export const __testing = { clampTransactions, CATEGORIES, CURRENCIES };
