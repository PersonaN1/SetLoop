# App Store: страница приложения

Тексты для App Store Connect на двух языках (SPEC D12, D19). Лимиты Apple: название и подзаголовок — 30 символов, промотекст — 170, ключевые слова — 100 байт (кириллица — 2 байта на букву, через запятую без пробелов, без слов из названия и подзаголовка), описание — 4000. Все тексты в лимитах.

## Общее

| Поле | Значение |
|---|---|
| Основная категория | Health & Fitness / Здоровье и фитнес |
| Дополнительная категория | Sports / Спорт |
| Возрастной рейтинг | 4+ (все ответы анкеты — «нет») |
| Цена | Бесплатно |
| Приватность | Data Not Collected (D11) |
| Privacy Policy URL | https://personan1.github.io/SetLoop/privacy/ |
| Support URL | https://personan1.github.io/SetLoop/support/ |
| Marketing URL | https://personan1.github.io/SetLoop/ |
| Copyright | 2026 Имя Фамилия (как в аккаунте разработчика) |

## Русский

**Название:** SetLoop

**Подзаголовок:** Интервальный таймер тренировок

**Промотекст** (можно менять без ревью):

Соберите таймер для тренировки любой сложности: блоки, сеты, любые сочетания. Звуки, голос и таймер на экране блокировки. Бесплатно и без рекламы.

**Ключевые слова:**

табата,кроссфит,emom,бокс,раунды,сеты,отдых,hiit,фитнес

**Описание:**

SetLoop — интервальный таймер для тренировки любой сложности. Соберите её из блоков и сетов — вся структура видна сразу на цветной полосе.

ВОЗМОЖНОСТИ
• Шаги: подготовка, работа, отдых, заминка — у каждого свой цвет.
• Блоки с повторами, например 20 секунд работы и 10 отдыха ×8.
• Сеты с отдыхом между ними.
• Готовые таймеры: табата и другие.
• До старта видно общее время, работу и отдых.

ВО ВРЕМЯ ТРЕНИРОВКИ
• Крупный отсчёт, видно издалека.
• Звуки, голос и вибрация перед сменой шага.
• Таймер на экране блокировки и в Dynamic Island, с паузой и пропуском.
• История всех тренировок.

НАСТРОЙКИ
• Звуки, голос, вибрация.
• Сигналы в беззвучном режиме.
• Пауза при звонке, экран не гаснет.
• Цвета шагов, светлая и тёмная тема.

Бесплатно, без рекламы и регистрации. Данные хранятся только на вашем iPhone.

Вопросы и идеи: t.me/setnewloop

## English

**Name:** SetLoop

**Subtitle:** Interval Workout Timer

**Promotional text:**

Build a timer for any workout: blocks, sets, any combination. Sounds, voice and a timer on the Lock Screen. Free, no ads.

**Keywords:**

hiit,tabata,crossfit,emom,circuit,round,boxing,rest,sets,reps,gym,fitness,exercise,training

**Description:**

SetLoop is an interval timer for any workout. Build it from blocks and sets — the whole structure is visible at a glance as one colored strip.

FEATURES
• Steps: prepare, work, rest, cooldown — each with its own color.
• Blocks with repeats, e.g. 20 seconds of work and 10 of rest ×8.
• Sets with rest between them.
• Ready-made timers: Tabata and more.
• Total time, work and rest shown before you start.

DURING THE WORKOUT
• Large countdown, readable from afar.
• Sounds, voice and vibration before each step change.
• Timer on the Lock Screen and in the Dynamic Island, with pause and skip.
• History of every workout.

SETTINGS
• Sounds, voice, vibration.
• Signals in Silent mode.
• Pause on calls, keep the screen on.
• Step colors, light and dark theme.

Free, no ads, no sign-up. Your data stays on your iPhone.

Questions and ideas: t.me/setnewloop

## Notes for App Review

English, в поле App Review Information → Notes:

> SetLoop needs no account or sign-in. To try it, tap the play button next to any of the example timers.
> The audio background mode is used to play step sounds and voice prompts while the screen is locked during a workout; without it the cues stop when the phone locks. Audio stops when the workout ends.
> Live Activity shows the current step on the Lock Screen and in the Dynamic Island; its pause and skip buttons control the running workout.

## Скриншоты

Готовые снимки 6.9″ (1320×2868, PNG без прозрачности) лежат в `docs/appstore/en/` и `docs/appstore/ru/`; для меньших экранов App Store масштабирует их сам. Загружать в этом порядке:

1. `1-list.png` — список таймеров: каждый таймер — цветная полоса.
2. `2-overview.png` — обзор таймера: структура и итоги до старта.
3. `3-editor.png` — редактор: блоки, циклы, сеты.
4. `4-workout.png` — тренировка: крупный отсчёт.
5. `5-lock.png` — Live Activity на экране блокировки.

Сняты в симуляторе iPhone 18 Pro Max (iOS 27), время в статус-баре 9:41, язык системы совпадает с языком снимков.
