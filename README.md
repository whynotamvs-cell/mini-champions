# MINI CHAMPIONS

Семейная Roblox-игра: игроки крошечные, спортивные площадки построены на огромных предметах письменного стола.
MVP — Obstacle Dash («Desk Dash») + собственный клуб + валюта Stars + сохранение прогресса.

Статус: **этап 0** — документация и окружение. Игровые системы ещё не реализованы.

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
selene src                                  # линт
stylua --check src                          # проверка форматирования
stylua src                                  # форматирование
rojo sourcemap --watch -o sourcemap.json    # для Luau LSP (VS Code делает это сам)
mkdir -p build && rojo build -o build/MiniChampions.rbxl   # сборка place-файла
```

## Структура

```text
src/server/        → ServerScriptService.Server
src/client/        → StarterPlayer.StarterPlayerScripts.Client
src/shared/        → ReplicatedStorage.Shared
src/localization/  → LocalizationService (UI.csv → LocalizationTable)
DevPackages/       → ReplicatedStorage.DevPackages (Wally, не в git)
```

Полная целевая структура — `docs/ARCHITECTURE.md`, раздел 3.
