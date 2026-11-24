# ARCHITECTURE.md — техническая архитектура MVP

> Версия: 1.0 · Связано: `CLAUDE.md`, `docs/DATA_SCHEMA.md`, `docs/ECONOMY.md`, `docs/TEST_PLAN.md`

## 1. Принципы

1. **Сервер авторитетен.** Клиент: ввод, UI, камера, звук, эффекты. Сервер: всё, что влияет на прогресс.
2. **Один владелец у каждого состояния.** Stars — `CurrencyService`, клуб — `ClubService`, забег — `MinigameService`. Остальные просят владельца, а не меняют сами.
3. **Конфиг отдельно от кода.** Цены, награды, пороги, тайминги — в `src/shared/Config/`.
4. **Явный порядок загрузки.** `Init()` всех сервисов (без yield) → `Start()` всех сервисов.
5. **Без фреймворков.** Knit и подобные не используем: для MVP достаточно простого загрузчика на ~40 строк. Меньше магии — проще читать и Claude Code, и человеку.

## 2. Инструменты (оценка и решение)

| Инструмент | Что делает | Решение | Примечание |
|---|---|---|---|
| **Rokit** | Устанавливает и закрепляет версии CLI-инструментов проекта (`rokit.toml`) | Использовать | Преемник Aftman/Foreman. Версии закрепляются при настройке, фиксируются в репозитории |
| **Rojo** | Синхронизирует `src/` с Studio, собирает `.rbxl` | Использовать | Плагин Rojo в Studio должен совпадать по версии с CLI |
| **Selene** | Линтер | Использовать | `selene.toml`: `std = "roblox"`. Запуск локально перед коммитом |
| **StyLua** | Форматтер | Использовать | `stylua.toml`: табы, ширина 120, двойные кавычки. Формат-при-сохранении в VS Code |
| **Luau LSP** | Типы и подсказки в VS Code | Использовать | Расширение VS Code + `rojo sourcemap --watch` |
| **Wally** | Пакетный менеджер | Только dev | Jest-Lua. ProfileStore — vendored (один файл, проще аудит) |
| **Jest-Lua** | Тесты | Использовать | Запуск внутри Studio через тест-раннер (см. TEST_PLAN) |
| **Lune** | Luau вне Roblox | Использовать (D6) | `lune run tests/lune/run.luau` гоняет `tests/specs` без Studio через виртуальное дерево инстансов и совместимый с Jest shim; плюс проверка локализации |
| **luau-lsp CLI** | Строгая проверка типов | Использовать | `tools/typecheck.sh` — тот же анализатор, что в VS Code; определения Roblox API скачиваются под закреплённую версию |
| Knit / Matter / Replica | Фреймворки | Не использовать в MVP | Лишняя сложность для объёма MVP |

### Файлы конфигурации (создаются на этапе 0)

```text
rokit.toml          — rojo, selene, stylua, wally (+ lune, если D6)
default.project.json
selene.toml
stylua.toml
wally.toml          — dev-dependencies: jest
.vscode/settings.json   — luau-lsp: sourcemap, formatOnSave, StyLua
.vscode/extensions.json — рекомендованные расширения
.gitignore          — sourcemap.json, build/, Packages/, DevPackages/, *.rbxl.lock
```

## 3. Структура репозитория

```text
mini-champions/
├── CLAUDE.md
├── PROJECT_PLAN.md
├── CHANGELOG.md
├── README.md
├── default.project.json
├── rokit.toml · selene.toml · stylua.toml · wally.toml
├── src/
│   ├── server/                         → ServerScriptService.Server
│   │   ├── Main.server.luau            — загрузчик сервисов
│   │   ├── Services/
│   │   │   ├── PlayerDataService.luau  — ЕДИНСТВЕННЫЙ require ProfileStore
│   │   │   ├── PlayerData/Migrations.luau
│   │   │   ├── PlayerData/Validate.luau
│   │   │   ├── CurrencyService.luau
│   │   │   ├── RewardService.luau
│   │   │   ├── ProgressionService.luau — XP, уровни
│   │   │   ├── TutorialService.luau
│   │   │   ├── ClubService.luau        — участки и улучшения
│   │   │   ├── MinigameService.luau    — общий жизненный цикл
│   │   │   ├── Minigames/ObstacleDash.luau
│   │   │   ├── EmoteService.luau
│   │   │   ├── ChatPolicyService.luau  — проверка, что чат выключен
│   │   │   └── TelemetryService.luau   — обёртка AnalyticsService
│   │   └── Vendor/ProfileStore.luau
│   ├── client/                         → StarterPlayer.StarterPlayerScripts.Client
│   │   ├── Main.client.luau
│   │   ├── Controllers/
│   │   │   ├── DataController.luau     — локальный снимок данных
│   │   │   ├── UIController.luau
│   │   │   ├── HudController.luau
│   │   │   ├── ClubMenuController.luau
│   │   │   ├── DashController.luau     — таймер, отсчёт, экран результата
│   │   │   ├── EmoteController.luau
│   │   │   ├── SettingsController.luau
│   │   │   ├── LocalizationController.luau
│   │   │   ├── ChatController.luau     — скрывает UI чата
│   │   │   ├── AudioController.luau
│   │   │   └── CameraController.luau
│   │   └── UI/                         — компоненты UI (код, а не .rbxm, где возможно)
│   ├── shared/                         → ReplicatedStorage.Shared
│   │   ├── Config/
│   │   │   ├── Economy.luau
│   │   │   ├── Dash.luau
│   │   │   ├── Emotes.luau
│   │   │   └── Game.luau               — MaxPlayers, флаги Studio
│   │   ├── Types/
│   │   ├── Net/
│   │   │   ├── Remotes.luau            — манифест всех remote
│   │   │   ├── Validators.luau
│   │   │   └── RateLimiter.luau
│   │   └── Utilities/
│   │       ├── Signal.luau
│   │       └── Formulas.luau           — уровень из XP, уровень клуба, медаль по времени
│   └── localization/                   → LocalizationService
│       └── UI.csv                      — LocalizationTable (en, ru)
├── assets/                             — исходники моделей (.rbxm) по мере появления
├── tests/                              — спецификации Jest-Lua
├── tools/                              — служебные скрипты (восстановление данных и т. п.)
└── docs/
```

### Фрагмент `default.project.json`

```json
{
  "name": "MiniChampions",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" },
      "Packages": { "$path": "Packages" }
    },
    "ServerScriptService": {
      "Server": { "$path": "src/server" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    },
    "LocalizationService": {
      "$path": "src/localization"
    },
    "Players": {
      "$properties": { "CharacterAutoLoads": true }
    }
  }
}
```

Точные свойства сервисов, которые Rojo может выставлять, проверить при настройке. Свойства, которые Rojo выставить не может (например, защищённые настройки TextChatService), выставляются в Studio и **проверяются при запуске сервера** (`ChatPolicyService`, раздел 7).

## 4. Загрузка

```luau
-- src/server/Main.server.luau (схема)
local services = {
	require(Services.TelemetryService),
	require(Services.PlayerDataService),
	require(Services.CurrencyService),
	require(Services.ProgressionService),
	require(Services.RewardService),
	require(Services.TutorialService),
	require(Services.ClubService),
	require(Services.MinigameService),
	require(Services.EmoteService),
	require(Services.ChatPolicyService),
}
for _, s in services do s:Init() end   -- создание remote, подписки; без yield
for _, s in services do task.spawn(s.Start, s) end
```

Клиент — аналогично с контроллерами; клиент ждёт снимок данных от сервера прежде чем показать HUD (экран «Loading…» с локализованным текстом).

## 5. Серверные сервисы

| Сервис | Ответственность | Публичный API (серверный) |
|---|---|---|
| `PlayerDataService` | Загрузка/сохранение, session lock, миграции, валидация, снимок для клиента | `IsReady(p)`, `Get(p)` (только чтение), `Update(p, fn)`, `SaveNow(p)`, сигнал `Loaded` |
| `CurrencyService` → `Logic/CurrencyLogic` | Единственный код, который меняет `Stars`. Реализован как чистый модуль, вызываемый внутри `PlayerDataService:Update`, чтобы списание и то, на что потрачено, менялись одной атомарной операцией | `credit(data, amount) -> added`, `debit(data, amount) -> boolean` |
| `RewardService` | Идемпотентные выдачи по `grantId` | `Grant(p, source, grantId, stars, xp)` |
| `ProgressionService` | XP и уровни, награда за уровень | `AddXP(p, amount, reason)` |
| `TutorialService` | Шаги обучения, продвигаются серверными событиями | `OnEvent(p, eventName)` |
| `ClubService` | Назначение участков, покупка улучшений, отрисовка улучшений на участке | `Purchase(p, index)` |
| `MinigameService` | Общий жизненный цикл, один активный забег на игрока | `GetActiveRun(p)` |
| `ObstacleDash` | Логика трасс (Desk Dash, Keyboard Dash) | см. раздел 8 |
| `EmoteService` | Проверка и рассылка эмоций | — |
| `ChatPolicyService` | Проверка, что чат выключен; удаляет любой появившийся `TextChannel` | — |
| `CollisionService` | Группа столкновений «Players» для всех частей персонажей (D12) | — |
| `TelemetryService` | События аналитики | `Onboarding(p, step)`, `Economy(...)`, `Progression(...)`, `Custom(...)` |

`Update(p, fn)`: вызывает `fn(data)` синхронно, затем валидацию; если `fn` выбросил ошибку или валидация не прошла — изменения откатываются (работаем с копией и подменяем только при успехе), клиенту отправляется обновлённый снимок.

## 6. Сеть

### 6.1. Манифест remote

Все remote перечислены в `src/shared/Net/Remotes.luau`. Создаёт их **сервер** в `Init()` в папке `ReplicatedStorage.Remotes`. Клиент получает их через `WaitForChild` с таймаутом.

| Remote | Направление | Аргументы | Валидация | Лимит |
|---|---|---|---|---|
| `PurchaseUpgrade` | C→S (RemoteFunction) | `index: number` | целое, 1..8, `== UpgradesOwned + 1`, профиль Ready | 2/с |
| `SendEmote` | C→S | `emoteId: string` | строка ≤ 32, есть в `Config.Emotes` | 1 / 2 с |
| `UpdateSettings` | C→S | `{ MusicVolume, SfxVolume, Language, ReducedMotion }` | типы, диапазоны, перечисление языков, лишние ключи отбрасываются | 2/с |
| `TutorialAck` | C→S | `step: number` | только шаг 3 «открыл меню клуба»; принимается, только если сохранённый шаг == 2 | 2/с |
| `RequestBoard` | C→S | — | клиент просит текущую таблицу результатов (профиль Ready не нужен) | 1/с |
| `RequestRestart` | C→S | — | игрок в активном забеге | 1/с |
| `RequestSnapshot` | C→S | — | профиль Ready; клиент просит первый снимок, когда его обработчики уже подключены | 1/с |
| `DataSnapshot` | S→C | снимок данных клиента | — | — |
| `DashEvent` | S→C | `{ kind, ... }` (countdown, start, checkpoint, finish, abandon) | — | — |
| `EmoteShown` | S→C | `userId, emoteId` | — | — |
| `BoardUpdate` | S→C | `{ {userId, name, timeMs, medal} }`, быстрейшие первыми, до 5 строк | только валидные финиши этого сервера; в профиль не пишется | — |
| `Notify` | S→C | `key: string, args?` | ключ локализации, а не текст | — |

Клиент **не присылает**: время забега, чекпоинты, финиш, суммы Stars, номер участка.

### 6.2. Обязательная обёртка обработчиков

```luau
Net.onServerEvent("SendEmote", {
	rate = { count = 1, per = 2 },
	validate = Validators.tuple(Validators.enumString(Config.Emotes.Ids)),
	requireReady = true,
}, function(player, emoteId)
	EmoteService:Show(player, emoteId)
end)
```

Обёртка: проверяет лимит частоты (токен-бакет на игрока и remote), количество и типы аргументов (`typeof`, `NaN`, `inf`, длина строк, глубина таблиц), готовность профиля; при нарушении — тихо отбрасывает и считает нарушения. Порог нарушений → `warn` + событие телеметрии `net_violation` (без кика в MVP, чтобы не наказывать за лаги).

### 6.3. Снимок данных клиенту (D5)

Сервер отправляет только то, что нужно UI: `Stars`, `Level`, `XPIntoLevel`, `XPForNext`, `ClubLevel`, `UpgradesOwned`, `Tutorial`, `DeskDash` и `KeyDash` (рекорд, медали по трассам), `Settings`. Отправка — после каждого `Update` с коалесцированием (не чаще раза в 0,2 с). Клиентские данные — только для показа; сервер их никогда не читает.

## 7. Коммуникация: чат выключен, эмоции включены

### 7.1. Отключение свободного чата (несколько слоёв)

| Слой | Где | Что |
|---|---|---|
| 1 | `default.project.json` → `TextChatService` | `CreateDefaultTextChannels = false` — нет каналов, значит сообщения некуда отправить и неоткуда получить; `CreateDefaultCommands = false`. По creator-docs (21.11.2026) оба свойства доступны скриптам, поэтому их выставляет Rojo. `ChatVersion` устарел и не трогается |
| 2 | Studio → дочерние конфигурации | `ChatWindowConfiguration.Enabled = false`, `ChatInputBarConfiguration.Enabled = false`, `BubbleChatConfiguration.Enabled = false`, `ChannelTabsConfiguration.Enabled = false` |
| 3 | `ChatController` (клиент) | При старте повторно выставляет `Enabled = false` у конфигураций окна и строки ввода (страховка, если свойство сбросили в Studio) |
| 4 | `ChatPolicyService` (сервер) | При старте проверяет: `CreateDefaultTextChannels == false`, в `TextChatService` нет `TextChannel`. Нарушение → `warn` + телеметрия `chat_policy_violation`. В тестовом experience — `error`, чтобы заметить сразу |
| 5 | Game Settings → Communication | Голосовой чат выключен (D7) |
| 6 | Код | Запрет в CLAUDE.md: никаких `TextChannel`, `TextBox`, видимых другим игрокам |

`CreateDefaultTextChannels` записывается только из Studio/плагина — отсюда проверка слоем 4. Точные имена свойств и расположение настройки голосового чата сверить в Studio при настройке; отметить результат в TEST_PLAN (C-01…C-05).

### 7.2. Эмоции

| ID | Иконка | Ключ локализации | Анимация (MVP) |
|---|---|---|---|
| `wave` | 👋-подобная иконка (своя) | `Emote.Wave` | Своя короткая анимация или подскок-заглушка |
| `cheer` | Кубок | `Emote.Cheer` | Прыжок |
| `clap` | Ладони | `Emote.Clap` | Заглушка |
| `thumbs_up` | Палец вверх | `Emote.ThumbsUp` | Заглушка |
| `gg` | Флажок финиша | `Emote.GoodGame` | Заглушка |
| `race` | Кроссовок | `Emote.LetsRace` | Заглушка |

Поток: игрок нажимает кнопку эмоций → колесо/сетка из 6 крупных иконок → `SendEmote(id)` → сервер проверяет ID и лимит → `EmoteShown(userId, id)` всем → у всех над головой игрока на 3 с появляется `BillboardGui` с иконкой и **локализованной для каждого зрителя** подписью. Текст никогда не приходит от игрока — только ID.

Иконки — собственные (не системные эмодзи, чтобы одинаково выглядело на всех платформах).

## 8. Obstacle Dash («Desk Dash», «Keyboard Dash»)

Один движок на несколько трасс. Всё, что отличается между трассами, описано в `src/shared/Config/Tracks.luau` (id, ключ данных, имя модели в мире, число чекпоинтов, минимумы по сегментам, порог падения, закрыта ли до конца обучения); числа медалей и таймаутов — в `Config/Economy.luau` (`Economy.Tracks`). Забег принадлежит одной трассе (`Run.track`), поэтому пределы и награды не смешиваются. В мире каждая трасса — модель под `Workspace.DeskWorld` (`DeskDash`, `KeyDash`) с папками `Geometry`, `Zones`, `Spawns` и деталью `ResultsBoard` у финиша. События `DashEvent` несут `track`; таблица результатов своя у каждой трассы (`BoardUpdate(trackId, entries)`). Закрытая трасса не стартует: сервер шлёт `{ kind = "locked" }`, клиент показывает подсказку.

**Мир — одна замкнутая квадратная комната** (400 × 400 студов, стены 150, потолок с девятью лампами с `PointLight`; генератор `tools/gen_world.py`): хаб с ковриком и шестью участками клубов у западной стены (лицом на восток), Desk Dash змейкой в северной половине, Keyboard Dash в южной; стартовые площадки рядом с хабом, дорожки-плитки и маяки ведут к ним. Всё остальное пространство занято гигантской канцелярией (полки с книгами у северной и южной стен, стойка карандашей у восточной, предметы на полу, расставленные по сетке с фиксированным seed). Генератор сам проверяет проходимость каждой пары соседних деталей трассы (расстояние + 1,5 × подъём ≤ 10, подъём ≤ 3, зазор ≤ 7,5) и печатает длину ходьбы и предложенные пределы для `Economy.Tracks`/`Tracks.SegmentMinMs`. Путь трассы (центры деталей) лежит в атрибуте `Path` модели трассы (для инструментов и тестов).

**Детали трасс:** каждая деталь трассы стоит на опоре до пола, на ней тематические украшения без коллизии (страницы книг, ластики и колпачки на карандашах, деления линейки, липкая полоса на стикерах; клавиши с пластиной и «буквой», кабель с разъёмами и хомутами; шашечный финиш, флажки на чекпоинтах). Украшения не влияют на геометрию трассы и проверку проходимости.

**Звуки трасс** (`Config/Sounds.luau`, `SoundController`, `tools/gen_sounds.py`, `assets/audio/`): отсчёт, GO, прыжок и приземление во время забега, чекпоинт, падение, финиш по медали. У каждой трассы один файл-«спрайт» со всеми репликами подряд, который игра проигрывает со смещения реплики и останавливает по её длине. Звуки **собственные**, синтезированы скриптом (маримба и дерево у Desk Dash, треугольные писки и клики у Keyboard Dash), без сэмплов и чужого аудио. Пока у трассы `asset = ""` (файл не загружен), она **без звука**: встроенные звуки движка оказались грубыми и убраны. Идёт через `SoundGroup` `Sfx`, громкость из настроек работает.

### 8.1. Состояния забега (сервер)

```text
(нет) ──вход на стартовую площадку──► Countdown (3 с)
Countdown ──сошёл с площадки──► (нет)
Countdown ──3 с прошло──► Running   [t0 = workspace:GetServerTimeNow()]
Running ──касание чекпоинта i (по порядку)──► Running [lastCheckpoint = i]
Running ──падение / Humanoid.Died──► Running [телепорт к lastCheckpoint]
Running ──касание финиша, все чекпоинты пройдены──► Finished [t = now - t0]
Running ──таймаут 180 с / выход игрока / RequestRestart──► Abandoned
Finished ──валидация пройдена──► Rewarded  (RewardService.Grant, grantId = "dash:"..runId)
Finished ──валидация провалена──► Rejected  (без награды, телеметрия dash_rejected)
```

Один активный забег на игрока. Все переходы — в `ObstacleDash`, синхронно.

### 8.2. Определение касаний

- Чекпоинты и финиш — невидимые серверные зоны (`Part`, `CanCollide = false`, `CanTouch = true`). Касание обрабатывается на **сервере** по `HumanoidRootPart` персонажа.
- Альтернатива/дополнение: опрос позиции `HumanoidRootPart` раз в 0,1 с и проверка попадания в зону (зоны не повёрнуты, поэтому достаточно проверки точки в прямоугольнике, без `GetPartBoundsInBox`) — устойчивее к пропуску `Touched` при высокой скорости. Выбор (D13) — на этапе 1 по результатам теста в Studio; оба способа реализованы, переключатель `Config.Dash.CheckpointDetection` (`"Poll"` по умолчанию / `"Touched"`).
- Геометрия трассы-заглушки генерируется `tools/gen_world.py` в `world/DeskWorld.model.json` (Rojo → `Workspace.DeskWorld`). Правки — в скрипте, затем перегенерация; ручные правки в Studio Rojo перезапишет.

### 8.3. Античит (без ложных наказаний)

| Проверка | Правило | Действие |
|---|---|---|
| Порядок чекпоинтов | Только `lastCheckpoint + 1` засчитывается | Пропуски игнорируются |
| Финиш без всех чекпоинтов | Не засчитывается | Игрок видит подсказку «пропущен чекпоинт» |
| Минимальное общее время | `≥ Config.Dash.MinValidTimeMs` | Rejected, без награды, без кика |
| Минимальное время сегмента | Для каждого сегмента своё (`Config.Dash.SegmentMinMs`) | Rejected |
| Скачок позиции | Перемещение > N studs за 0,1 с вне телепорта сервера | Отметка `suspicious`, забег Rejected |
| Время — только серверное | `GetServerTimeNow()` на старте и финише | Клиентское время не используется |

Клиент показывает таймер по `t0`, полученному в `DashEvent`; это только визуализация.

### 8.4. Несколько игроков

Забеги независимы: каждый игрок бежит свой забег, но в общем мире (видно других игроков). Столкновения между игроками отключены через `CollisionGroup` «Players» (не мешают друг другу, нельзя сталкивать с трассы). Табло у финиша показывает лучшие времена игроков **текущего сервера** за сессию (отображаемые имена Roblox, без нашего хранения).

## 9. Клуб

- `Config.Game.MaxPlayers = 6`, участков 6 (D2). Количество игроков сервера выставляется в настройках experience так же.
- Участок назначается при входе (первый свободный), освобождается при выходе. Не сохраняется.
- Улучшения — заранее подготовленные модели в `ServerStorage.ClubUpgrades/<id>`; при загрузке профиля и после покупки сервер клонирует нужные модели на участок игрока.
- На участок может зайти любой игрок, но взаимодействовать с меню клуба может только владелец (меню открывается клиентом владельца; сервер в `Purchase` всё равно проверяет только собственные данные игрока — чужой клуб изменить невозможно по построению).

## 10. Локализация

### 10.1. Устройство

- Исходник — `src/localization/UI.csv` → Rojo создаёт `LocalizationTable` в `LocalizationService`.
- Колонки: `Key, Source, Context, Example, en, ru`.
- Ключи — иерархические: `HUD.Stars`, `Club.Upgrade.pencil_fence.Name`, `Dash.Result.Gold`, `Error.LoadFailed`.
- Форматирование с параметрами: `Dash.Result.Time` = `"Time: {time}"` / `"Время: {time}"`.
- Множественные формы: русскому нужны три формы («1 звезда», «2 звезды», «5 звёзд»). В MVP избегаем числа + существительного в одной строке: показываем иконку звезды и число (`⭐ 120`). Если всё же нужно — свой хелпер `Plural.ru(n, one, few, many)` с ключами `.One/.Few/.Many`.

### 10.2. Выбор языка

1. `Settings.Language == "auto"` → `LocalizationService:GetTranslatorForPlayerAsync(player)` (язык аккаунта; неподдерживаемые языки → английский).
2. `"en"` / `"ru"` → `LocalizationService:GetTranslatorForLocaleAsync(locale)`.
3. `LocalizationController` хранит текущий `Translator`, все UI-компоненты берут строки через `L(key, args)`; смена языка в настройках перерисовывает UI без перезахода.

### 10.3. Правила

- У динамических `TextLabel` — `AutoLocalize = false` (текст ставит наш контроллер). Автоматический перевод Roblox не используем как основной источник.
- Сервер отправляет клиенту **ключи**, не готовый текст.
- Проверка в тестах: каждый ключ, используемый в коде, есть в CSV; у каждой строки заполнены `en` и `ru`.
- Русский текст в среднем на 20–30% длиннее английского — UI проектируется с запасом ширины; `TextScaled` с `UITextSizeConstraint` (минимум читаемого размера).

## 11. UI — Mobile First

| Правило | Значение |
|---|---|
| Базовое разрешение макета | 844×390 (горизонтальный телефон) |
| Масштабирование | `UIScale` от короткой стороны экрана; позиции в `Scale` |
| Безопасная зона | `ScreenGui.ScreenInsets = CoreUISafeInsets` (не перекрывать кнопки Roblox и вырез экрана) |
| Минимальная кнопка | ~48×48 px в базовом разрешении |
| Зоны | Слева снизу — джойстик Roblox (не занимать); справа снизу — прыжок (не занимать); HUD — сверху; кнопки меню — справа по центру |
| Текст | Минимум 14 px в базовом разрешении; иконка рядом с каждым важным действием |
| ПК | Те же экраны, плюс горячие клавиши (`C` — клуб, `E` — эмоции, `Esc` — закрыть) и подсказки к кнопкам |
| Геймпад | Не в MVP, но не ломать: навигация по выделению (`Selectable`) у кнопок меню |
| Доступность | Уменьшение движения (без тряски камеры и резких анимаций), не передавать информацию только цветом |

Экраны MVP: Loading, HUD, Club Menu, Dash HUD (отсчёт, таймер, чекпоинт), Dash Result, Emote Wheel, Settings, сообщение об ошибке загрузки.

## 12. Аналитика (AnalyticsService)

Все вызовы — только на сервере, только через `TelemetryService`. В Studio `TelemetryService` пишет в `print` и не вызывает `AnalyticsService` (флаг `Config.Game.TelemetryInStudio`).

### 12.1. Воронка обучения — `LogOnboardingFunnelStepEvent`

Каждый шаг логируется один раз за жизнь игрока (защита — `Tutorial.Step` в профиле).

| Шаг | Имя | Когда |
|---|---|---|
| 1 | `Joined` | Первый вход, профиль загружен |
| 2 | `ReachedDashStart` | Встал на стартовую площадку |
| 3 | `StartedFirstRun` | Отсчёт закончился |
| 4 | `ReachedCheckpoint2` | Половина трассы |
| 5 | `FinishedFirstRun` | Первый финиш |
| 6 | `OpenedClubMenu` | Открыл меню клуба |
| 7 | `BoughtFirstUpgrade` | Первая покупка |
| 8 | `TutorialComplete` | Обучение завершено |

### 12.2. Экономика — `LogEconomyEvent`

Каждое изменение Stars: `flowType` (Source/Sink), валюта `"Stars"`, сумма, баланс после, `transactionType`, `itemSku`. Таблица — ECONOMY.md, раздел 8.

### 12.3. Прогресс — `LogProgressionEvent` (или раздельные Start/Complete/Fail)

`progressionPathName` = `Config.Tracks[id].Progression` (`"DeskDash"` или `"KeyDash"`), уровень 1, статус: начало / завершение / провал (Abandoned/Rejected).

### 12.4. Пользовательские события — `LogCustomEvent`

| Событие | Значение |
|---|---|
| `DashFinishTimeSec` | Время забега |
| `DashMedal` | 1/2/3 |
| `SessionRuns` | Забегов за сессию (при выходе) |
| `EmoteUsed` | 1 (custom field — ID эмоции) |
| `NetViolation` | 1 |
| `DataLoadFailed` | 1 |

Ограничения AnalyticsService (число custom fields, их уникальных значений, шагов воронки) сверить при реализации; в custom fields — только ID из наших перечислений, никаких свободных строк и личных данных.

## 13. Производительность (ориентиры для мобильных)

| Метрика | Цель |
|---|---|
| Инстансов в Workspace | < 15 000 |
| Активных физических частей | Минимум; декор — `Anchored`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false` где возможно |
| Движущиеся препятствия | Сервер управляет через `TweenService`/`AlignPosition`, не через цикл каждый кадр на каждом объекте |
| StreamingEnabled | Включить; хаб и трасса — в пределах стандартного радиуса; `ModelStreamingMode` для улучшений клуба |
| Текстуры | Цвет и материалы вместо текстур, где возможно |
| Сетевой трафик | Снимок данных с коалесцированием; без отправки событий каждый кадр |

Проверка — MicroProfiler и Developer Console (`F9`) в Studio и на реальном телефоне.

## 14. Окружения

| Окружение | Где | DataStore |
|---|---|---|
| Локальная разработка | Studio, без публикации | `ProfileStore.Mock` |
| Тестовый experience | Отдельный experience в Creator Hub, приватный | Реальный, изолированный |
| Боевой experience | Публичный | Реальный |

### 14.1. Идентификаторы

| Окружение | Название | Universe ID | Place ID |
|---|---|---|---|
| Тестовый | Mini Champions [TEST] | `10778182955` | `137418142134310` |
| Боевой | — | ещё не создан | ещё не создан |

ID не являются секретами и хранятся в репозитории. На этапе 1 переносятся в `src/shared/Config/Game.luau`: реальный DataStore в Studio разрешён, только если `game.PlaceId` совпадает с тестовым Place ID **и** `Config.Studio.UseRealDataStore = true`; во всех остальных случаях — `ProfileStore.Mock` (DATA_SCHEMA.md, раздел 3).

Публикация в боевой — только вручную владельцем по `docs/RELEASE_CHECKLIST.md`.
