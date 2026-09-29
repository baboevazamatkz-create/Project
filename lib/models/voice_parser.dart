import 'expense_category.dart';
import 'voice_intent.dart';

/// Reads the plain, common phrasings of a voice command on the device, with
/// no network at all: "потратил 500 на такси", "получил зарплату 80 000",
/// "сколько я потратил на продукты вчера".
///
/// The fallback behind the worker's /voice route, not a replacement for
/// it. The model understands far looser speech; this covers what people
/// actually say most of the time, so the assistant keeps working when the
/// worker can't be reached, is over its daily quota, or is still running a
/// version from before /voice existed -- which is exactly how the first
/// release of this feature reached people: a phrase heard perfectly and
/// then answered with the scanner's "Пустой снимок".
///
/// Deliberately conservative: it only returns a record when it found an
/// amount, and a question only when the phrase asks one ("сколько ...").
/// Anything else is [VoiceUnclearIntent] rather than a guess, and a record
/// still goes through the confirmation sheet before it is written.
VoiceIntent parseVoiceCommand(String text, {required DateTime today}) {
  final normalized = _normalize(text);
  if (normalized.isEmpty) return const VoiceUnclearIntent();
  final words = _words(normalized);

  if (_isQuestion(normalized, words)) {
    final type = _queryType(normalized, words);
    return VoiceQueryIntent(
      type: type,
      category:
          type == VoiceQueryType.income ? null : _category(words)?.category,
      period: _period(normalized, words),
    );
  }

  final amount = _amount(normalized, words);
  if (amount == null || amount <= 0) return const VoiceUnclearIntent();

  final income = _incomeMatch(normalized, words);
  if (income != null) {
    return VoiceAddIntent(
      type: VoiceRecordType.income,
      amount: amount,
      category: null,
      date: _date(words, today),
      note: income,
    );
  }

  final match = _category(words);
  return VoiceAddIntent(
    type: VoiceRecordType.expense,
    amount: amount,
    category: match?.category ?? ExpenseCategory.other,
    date: _date(words, today),
    note: match?.note ?? '',
  );
}

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^0-9a-zа-я₽$₸.,\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Words with sentence punctuation stripped, for keyword matching. Numbers
/// are read from the normalized string instead, where "1,5" still means
/// one and a half.
List<String> _words(String normalized) => normalized
    .split(' ')
    .map((w) => w.replaceAll(RegExp(r'[.,]'), ''))
    .where((w) => w.isNotEmpty)
    .toList();

/// A stem starting with "=" must match the whole word; any other is a word
/// beginning, so "продукт" catches "продукты" and "продуктов" alike. Whole
/// words are for stems whose beginnings collide with something common --
/// "пришло" (income) is also the start of "пришлось" ("had to").
bool _matches(String word, String stem) =>
    stem.startsWith('=') ? word == stem.substring(1) : word.startsWith(stem);

bool _anyWordMatches(List<String> words, List<String> stems) =>
    words.any((w) => stems.any((stem) => _matches(w, stem)));

// --- questions ----------------------------------------------------------

const _questionOpeners = [
  'покажи',
  'какие',
  'какой',
  'какая',
  'каков',
  'какова',
];

/// "Сколько ..." is always a question. "Какие / покажи ..." is one only
/// when no figure was said: "какой-то кофе 300" is a record, not a query.
bool _isQuestion(String normalized, List<String> words) {
  if (words.contains('сколько')) return true;
  return words.isNotEmpty &&
      _questionOpeners.contains(words.first) &&
      !RegExp(r'\d').hasMatch(normalized);
}

const _incomeQueryStems = [
  'заработ',
  'доход',
  'получил',
  'зарплат',
  'поступ',
  '=пришло',
  '=пришли',
];
const _netQueryStems = ['осталось', 'остал', 'сэконом', 'баланс', 'разниц'];

VoiceQueryType _queryType(String normalized, List<String> words) {
  if (_anyWordMatches(words, _netQueryStems) ||
      normalized.contains('в плюсе') ||
      normalized.contains('в минусе')) {
    return VoiceQueryType.net;
  }
  if (_anyWordMatches(words, _incomeQueryStems)) {
    return VoiceQueryType.income;
  }
  return VoiceQueryType.expense;
}

VoiceQueryPeriod _period(String normalized, List<String> words) {
  if (words.contains('сегодня')) return VoiceQueryPeriod.today;
  if (words.contains('вчера')) return VoiceQueryPeriod.yesterday;
  if (_anyWordMatches(words, ['недел'])) return VoiceQueryPeriod.thisWeek;
  if (_anyWordMatches(words, ['прошл']) && _anyWordMatches(words, ['месяц'])) {
    return VoiceQueryPeriod.lastMonth;
  }
  if (normalized.contains('за все время') ||
      normalized.contains('за всю историю') ||
      words.contains('вообще')) {
    return VoiceQueryPeriod.all;
  }
  return VoiceQueryPeriod.thisMonth;
}

// --- dates ---------------------------------------------------------------

DateTime _date(List<String> words, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  if (words.contains('позавчера')) {
    return day.subtract(const Duration(days: 2));
  }
  if (words.contains('вчера')) return day.subtract(const Duration(days: 1));
  return day;
}

// --- income --------------------------------------------------------------

/// Words that make a record income rather than an expense, each with the
/// note it leaves on the record -- empty for verbs, which say how the money
/// came but not what it was.
const _incomeNotes = <String, String>{
  'зарплат': 'Зарплата',
  // Whole words: "премьера" is a film opening, not a bonus.
  '=премия': 'Премия',
  '=премию': 'Премия',
  '=премии': 'Премия',
  'аванс': 'Аванс',
  'кэшбэк': 'Кэшбэк',
  'кешбэк': 'Кэшбэк',
  'кешбек': 'Кэшбэк',
  'возврат': 'Возврат',
  'доход': '',
  'получил': '',
  'заработал': '',
  // Whole words: "пришлось заплатить" ("had to pay") is an expense.
  '=пришло': '',
  '=пришли': '',
  '=пришла': '',
  'поступ': '',
  'вернули': '',
  'продал': '',
};

/// Null when the phrase isn't about income; otherwise the note for it.
String? _incomeMatch(String normalized, List<String> words) {
  String? note;
  for (final word in words) {
    for (final entry in _incomeNotes.entries) {
      if (!_matches(word, entry.key)) continue;
      // A noun wins over a verb: "получил зарплату" should say Зарплата.
      if (note == null || note.isEmpty) note = entry.value;
    }
  }
  if (note == null && normalized.contains('перевели мне')) note = '';
  return note;
}

// --- categories ----------------------------------------------------------

class _CategoryMatch {
  final ExpenseCategory category;
  final String note;
  const _CategoryMatch(this.category, this.note);
}

/// Checked in this order, most specific first, so that "еду на такси"
/// ("I'm riding a taxi") lands in transport rather than on "еду" (food),
/// and a toy ("игрушка") in shopping rather than on "игр" (games). Stems
/// follow [_matches].
const _categoryStems = <ExpenseCategory, List<String>>{
  ExpenseCategory.transport: [
    'такси',
    'метро',
    'автобус',
    'бензин',
    'топлив',
    'заправ',
    'проезд',
    'транспорт',
    'парковк',
    'каршеринг',
    'электричк',
    'поезд',
    'самолет',
    'авиабилет',
    'трамва',
    'троллейбус',
    'маршрутк',
    'самокат',
    'автомойк',
    'шиномонтаж',
    'uber',
    'убер',
  ],
  ExpenseCategory.health: [
    'аптек',
    'лекарств',
    'таблетк',
    'врач',
    'больниц',
    'клиник',
    'здоров',
    'стоматолог',
    'зубн',
    'анализ',
    'фитнес',
    'спортзал',
    'тренажер',
    'тренировк',
    'бассейн',
    'массаж',
    'витамин',
  ],
  ExpenseCategory.housing: [
    'квартир',
    'аренд',
    'жкх',
    'коммунал',
    'квартплат',
    'электроэнерг',
    'электричеств',
    'интернет',
    'ипотек',
    'жиль',
    'связь',
    'мобильн',
    'ремонт',
  ],
  ExpenseCategory.shopping: [
    'покупк',
    'одежд',
    'обув',
    'кроссовк',
    'куртк',
    'джинс',
    'футболк',
    'плать',
    'подар',
    'косметик',
    'маркетплейс',
    'озон',
    'ozon',
    'вайлдберриз',
    'wildberries',
    'мебел',
    'техник',
    'ноутбук',
    'наушник',
    'телефон',
    'смартфон',
    'бытов',
    'хозтовар',
    'игрушк',
  ],
  ExpenseCategory.entertainment: [
    'кино',
    'развлеч',
    'игр',
    'концерт',
    'театр',
    '=бар',
    'клуб',
    'подписк',
    'нетфликс',
    'netflix',
    'музык',
    'отдых',
    'путешеств',
    'отпуск',
    'боулинг',
    'караоке',
    'музе',
    'аттракцион',
    'кальян',
  ],
  ExpenseCategory.food: [
    '=еда',
    '=еду',
    '=еды',
    '=едой',
    'продукт',
    'кафе',
    'ресторан',
    'обед',
    'ужин',
    'завтрак',
    'кофе',
    'пицц',
    'суши',
    'ролл',
    'бургер',
    'шаурм',
    'фастфуд',
    'столов',
    'перекус',
    'хлеб',
    'молок',
    'мясо',
    'фрукт',
    'овощ',
    'доставк',
    'пятерочк',
    'магнит',
    'перекресток',
    'ашан',
    'вкусвилл',
    'макдональдс',
    'kfc',
    '=чай',
    'пиво',
  ],
};

/// Words that name the category itself rather than a thing bought in it --
/// "на еду" says nothing a note would add.
const _genericWords = {'еда', 'еду', 'еды', 'едой', 'покупки', 'покупку'};

_CategoryMatch? _category(List<String> words) {
  for (final entry in _categoryStems.entries) {
    for (final word in words) {
      for (final stem in entry.value) {
        if (!_matches(word, stem)) continue;
        return _CategoryMatch(
          entry.key,
          _genericWords.contains(word) ? '' : word,
        );
      }
    }
  }
  return null;
}

// --- amounts -------------------------------------------------------------

/// A number as speech recognisers write it: "500", "1500", "1 500" (the
/// thousands grouped with a space), "1,5".
final _numberPattern =
    RegExp(r'\d{1,3}(?:\s\d{3})+(?:[.,]\d+)?|\d+(?:[.,]\d+)?');
final _thousandsAfter = RegExp(r'^\s*(?:тыс|тыщ)');
final _kAfter = RegExp(r'^к(?=\s|$)');
final _millionsAfter = RegExp(r'^\s*(?:млн|миллион)');
final _currencyAfter =
    RegExp(r'^\s*(?:тыс\S*\s*|тыщ\S*\s*|млн\S*\s*|миллион\S*\s*|к\s+)?'
        r'(?:руб|р(?=\s|$|\.)|₽|тенге|тг|₸|доллар|бакс|\$|usd)');
final _notAnAmountAfter = RegExp(
    r'^\s*(?:январ|феврал|март|апрел|ма[яй]|июн|июл|август|сентябр|октябр|'
    r'ноябр|декабр|год|час|минут|числ)');

double? _amount(String normalized, List<String> words) {
  final candidates = <({double value, bool hasCurrency})>[];
  for (final match in _numberPattern.allMatches(normalized)) {
    final after = normalized.substring(match.end);
    // "25 сентября", "2026 года", "в 8 часов" are when, not how much.
    if (_notAnAmountAfter.hasMatch(after)) continue;

    var value = double.tryParse(
        match[0]!.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));
    if (value == null) continue;
    if (_thousandsAfter.hasMatch(after) || _kAfter.hasMatch(after)) {
      value *= 1000;
    } else if (_millionsAfter.hasMatch(after)) {
      value *= 1000000;
    }
    candidates.add((value: value, hasCurrency: _currencyAfter.hasMatch(after)));
  }

  if (candidates.isNotEmpty) {
    // A figure said with its currency is the amount; otherwise the largest
    // one is, which keeps "2 кофе за 300" from recording two roubles.
    final withCurrency = candidates.where((c) => c.hasCurrency);
    final pool = withCurrency.isNotEmpty ? withCurrency : candidates;
    return pool.map((c) => c.value).reduce((a, b) => a > b ? a : b);
  }
  return _amountInWords(words);
}

const _numberWords = <String, double>{
  'ноль': 0,
  'один': 1,
  'одна': 1,
  'одну': 1,
  'одно': 1,
  'два': 2,
  'две': 2,
  'три': 3,
  'четыре': 4,
  'пять': 5,
  'шесть': 6,
  'семь': 7,
  'восемь': 8,
  'девять': 9,
  'десять': 10,
  'одиннадцать': 11,
  'двенадцать': 12,
  'тринадцать': 13,
  'четырнадцать': 14,
  'пятнадцать': 15,
  'шестнадцать': 16,
  'семнадцать': 17,
  'восемнадцать': 18,
  'девятнадцать': 19,
  'двадцать': 20,
  'тридцать': 30,
  'сорок': 40,
  'пятьдесят': 50,
  'шестьдесят': 60,
  'семьдесят': 70,
  'восемьдесят': 80,
  'девяносто': 90,
  'сто': 100,
  'двести': 200,
  'триста': 300,
  'четыреста': 400,
  'пятьсот': 500,
  'шестьсот': 600,
  'семьсот': 700,
  'восемьсот': 800,
  'девятьсот': 900,
  'полтора': 1.5,
  'полторы': 1.5,
  'полтысячи': 500,
};

const _multiplierWords = <String, double>{
  'тысяча': 1000,
  'тысячи': 1000,
  'тысяч': 1000,
  'тыща': 1000,
  'тыщи': 1000,
  'тыщ': 1000,
  'миллион': 1000000,
  'миллиона': 1000000,
  'миллионов': 1000000,
};

/// "пятьсот", "полторы тысячи", "две тысячи триста" -- for the recognisers
/// that spell numbers out instead of writing digits. Reads the first run of
/// number words and stops at the first word that isn't one.
double? _amountInWords(List<String> words) {
  var total = 0.0;
  var current = 0.0;
  var started = false;
  for (final word in words) {
    final number = _numberWords[word];
    final multiplier = _multiplierWords[word];
    if (number != null) {
      current += number;
      started = true;
    } else if (multiplier != null) {
      total += (current == 0 ? 1 : current) * multiplier;
      current = 0;
      started = true;
    } else if (started) {
      break;
    }
  }
  if (!started) return null;
  return total + current;
}
