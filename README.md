# Solidus

Совместный учёт расходов и доходов: общий бюджет на несколько человек,
Android и веб из одного кода.

## Возможности

- Общий бюджет по коду: записи видны всем участникам сразу (Firebase
  Firestore, анонимный вход)
- Расходы и доходы: сумма, категория (Еда, Транспорт, Жильё, Развлечения,
  Здоровье, Покупки, Другое), заметка, дата
- Список подряд или траты месяца, собранные по категориям
- Статистика: диаграмма по категориям, лимиты, итоги за полгода
- Рубли, тенге и доллары; приблизительный пересчёт для взгляда со стороны
- Сканер чеков и банковских скриншотов — распознаёт суммы, даты и
  категории, добавляет после подтверждения (см. `worker/README.md`)
- Виджет на домашний экран Android: клавиатура, выбор категории, запись
  прямо в бюджет
- Светлая и тёмная тема, несколько бюджетов, обучающий тур

## Запуск

```bash
flutter pub get
flutter run
```

Сканер подключается адресом воркера:

```bash
flutter run --dart-define=SCAN_ENDPOINT=https://solidus-scan.<имя>.workers.dev
```

Без него приложение работает как обычно — кнопка сканера просто не
показывается.

## Сборки

- **APK** — GitHub Actions на каждый push в `main`. Постоянная ссылка на
  последнюю сборку:
  https://github.com/baboevazamatkz-create/Project/releases/latest/download/Solidus.apk
- **Веб** — GitHub Pages, публикуется тем же push:
  https://baboevazamatkz-create.github.io/Project/

Локально:

```bash
flutter build apk --release
flutter build web --release --base-href /Project/
flutter build appbundle --release   # то, что принимает Google Play
```

Публикация в Play расписана по шагам в [`store/README.md`](store/README.md).
Политика конфиденциальности:
https://baboevazamatkz-create.github.io/Project/privacy.html

## Из чего состоит

| Каталог | Что там |
| --- | --- |
| `lib/` | приложение |
| `android/app/src/main/kotlin/.../SolidusWidgetProvider.kt` | виджет домашнего экрана |
| `worker/` | посредник для сканера (Cloudflare Worker) |
| `tool/generate_launcher_icon.py` | иконки и знак, генерируются, не рисуются руками |
| `store/` | всё для публикации в Google Play: тексты карточки, ответы на анкеты, графика |
| `test/` | тесты |
