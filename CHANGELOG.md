# CHANGELOG

Формат — по мотивам [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/).
Выводы из экспериментов закрытого теста (гипотеза → изменение → метрика → вывод) тоже записываются сюда.

## [Unreleased]

### Добавлено — этап 1, вертикальный срез (ветка `stage-1/vertical-slice`, 21–22.11.2026)

- Каркас: загрузчики Init/Start, конфиги (Economy = ECONOMY.md, Dash, Game), формулы, сетевой слой
  (лимит частоты → валидация → проверка Ready на каждом обработчике).
- Данные: ProfileStore 1.0.3 (vendored, Apache-2.0) за `PlayerDataService`; Mock в Studio; миграции,
  валидация с откатом, немедленное сохранение после покупки и первых медалей (D4).
- Награды: идемпотентность по `grantId` + постоянные флаги, лимиты ECONOMY.md 6, бонус за уровень.
- Desk Dash: серая трасса ~650 studs, 4 чекпоинта, серверная машина состояний, античит (минимальное
  время, сегменты, скачки позиции), возврат к чекпоинту при падении и гибели (D14), переключатель D13.
- Клуб: 6 участков, покупка улучшения №1 (`sticky_banner`) строго по порядку.
- Чат выключен (свойства в `default.project.json` + клиент + серверная проверка), столкновения игроков выключены (D12).
- UI Mobile First, локализация en + ru (44 ключа), минимальное обучение, воронка онбординга.
- Тесты: 82 юнит-теста в Lune + проверка локализации; строгая проверка типов `tools/typecheck.sh`.
- Изменение в DATA_SCHEMA.md 5: миграция выполняется до `Reconcile`.


### Добавлено — этап 0 (21.11.2026)

- Документация: `PROJECT_PLAN.md` v2.0, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/DATA_SCHEMA.md`, `docs/ECONOMY.md`, `docs/TEST_PLAN.md`.
- Решения D1–D14 приняты владельцем 20.11.2026.
- Инструменты закреплены в `rokit.toml`: Rojo 7.7.1, Selene 0.32.0, StyLua 2.6.0, Wally 0.3.2.
- Каркас репозитория: `default.project.json`, `selene.toml`, `stylua.toml`, `wally.toml` (dev: Jest-Lua 3.10.0), `.vscode/`, `.gitignore`, `README.md`.
- Пустые папки `src/server`, `src/client`, `src/shared` и заголовок `src/localization/UI.csv` (en, ru).
- Плагин Rojo 7.7.1 установлен; `rojo serve` + Connect в Studio показывает синхронизированное дерево (проверено владельцем).
- `wally install`: Jest-Lua 3.10.0 и JestGlobals 3.10.0 → `DevPackages/` (`ReplicatedStorage.DevPackages`), `wally.lock` в репозитории. На Apple Silicon Wally 0.3.2 требует Rosetta 2.
- Создан приватный тестовый experience «Mini Champions [TEST]» (D3): Universe `10778182955`, Place `137418142134310`. ID записаны в `docs/ARCHITECTURE.md` (14.1) и `docs/DATA_SCHEMA.md`.
- **Этап 0 завершён.**
