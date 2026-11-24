# MINI CHAMPIONS

Семейная Roblox-игра: игроки крошечные, спортивные площадки построены на огромных предметах письменного стола.
MVP — Obstacle Dash («Desk Dash») + собственный клуб + валюта Stars + сохранение прогресса.

Статус: **этап 1** — вертикальный срез на заглушках (ветка `stage-1/vertical-slice`), ждёт ручной проверки в Studio.

## Документы

| Документ | О чём |
|---|---|
| [`PROJECT_PLAN.md`](PROJECT_PLAN.md) | Видение, MVP, этапы, принятые решения D1–D14 |
| [`CLAUDE.md`](CLAUDE.md) | Постоянные правила для Claude Code |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Сервисы, сеть, чат, локализация, UI |
| [`docs/DATA_SCHEMA.md`](docs/DATA_SCHEMA.md) | Данные игрока, ProfileStore, миграции |
| [`docs/ECONOMY.md`](docs/ECONOMY.md) | Награды, цены, темп |
| [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md) | Уровни проверки и сценарии |
| [`CHANGELOG.md`](CHANGELOG.md) | История изменений |

## Что нужно установить

- **Roblox Studio** — https://create.roblox.com
- **Git**
- **VS Code** — при открытии папки предложит рекомендованные расширения (Luau LSP, StyLua, Selene, Rojo)
- **Rokit** — менеджер версий CLI-инструментов:
  ```bash
  curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
  ```
- macOS на Apple Silicon: Wally 0.3.2 собран только под Intel, нужен Rosetta 2:
  ```bash
  softwareupdate --install-rosetta --agree-to-license
  ```

## Первый запуск

```bash
git clone https://github.com/whynotamvs-cell/mini-champions.git
cd mini-champions
rokit install          # rojo, selene, stylua, wally — версии из rokit.toml
wally install          # dev-зависимости (Jest-Lua) → DevPackages/
rojo serve             # сервер синхронизации на localhost:34872
```

В Studio: установить плагин Rojo **той же версии, что CLI** (`rojo plugin install` или через Toolbox / VS Code-расширение Rojo), открыть пустой Baseplate, в панели Rojo нажать **Connect**.

## Повседневные команды

```bash
selene src tests/specs                      # линт
stylua --check src tests                    # проверка форматирования (stylua src tests — исправить)
./tools/typecheck.sh                        # строгая проверка типов (luau-lsp analyze)
lune run tests/lune/run.luau                # юнит-тесты + проверка локализации, без Studio
python3 tools/gen_world.py                  # перегенерировать серую геометрию мира
mkdir -p build && rojo build -o build/MiniChampions.rbxl   # сборка place-файла
```

## Тесты

- **Без Studio:** `lune run tests/lune/run.luau` — все `tests/specs/*.spec.luau` (чистая логика: формулы, экономика, валидаторы, награды, покупки, забег, миграции) и проверка `UI.csv`.
- **В Studio (Jest-Lua):** нужен флаг `FFlagEnableLoadModule` в `ClientAppSettings.json` Studio (см. документацию Jest-Lua). Затем в Play, в командной строке на стороне сервера: `require(game.ServerStorage.Tests.RunTests)()`.

## Данные в Studio

По умолчанию Studio использует `ProfileStore.Mock` — ничего не сохраняется между запусками. Для проверки сохранений (TEST_PLAN, S-01…S-10) — только в тестовом experience: включить `Config.Game.Studio.UseRealDataStore = true` в `src/shared/Config/Game.luau` (не коммитить) и Game Settings → Security → Enable Studio Access to API Services.

## Структура

```text
src/server/        → ServerScriptService.Server
src/client/        → StarterPlayer.StarterPlayerScripts.Client
src/shared/        → ReplicatedStorage.Shared
src/localization/  → LocalizationService (UI.csv → LocalizationTable)
world/             → Workspace.DeskWorld, ServerStorage.ClubUpgrades (генерирует tools/gen_world.py)
tests/specs/       → ServerStorage.Tests (спецификации, общие для Lune и Jest-Lua)
DevPackages/       → ReplicatedStorage.DevPackages (Wally, не в git)
```

Полная целевая структура — `docs/ARCHITECTURE.md`, раздел 3.
