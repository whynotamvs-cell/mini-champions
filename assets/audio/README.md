# Звуки трасс

`desk.wav` и `keys.wav` — **собственные** звуки игры, синтезированы скриптом `tools/gen_sounds.py`
(без сэмплов и чужого аудио; результат детерминирован). В каждом файле все реплики подряд («спрайт»):
отсчёт, GO, прыжок, приземление, чекпоинт, падение, финиш (Bronze/Silver/Gold), отказ. Смещения и
длины реплик — в `tools/gen_sounds.py` (`SLOTS`) и `src/shared/Config/Sounds.luau`; они должны совпадать.

- Desk Dash — тёплая маримба и дерево.
- Keyboard Dash — яркие треугольные писки и чистые клики клавиш.

## Как включить

1. Прослушайте оба файла (они лежат здесь). Если не нравится — правьте `tools/gen_sounds.py`
   (ноты, огибающие, громкости) и запустите `python3 tools/gen_sounds.py`.
2. Загрузите каждый файл как **Audio** в Creator Hub (Creations → Audio → Upload; или Open Cloud,
   см. ниже) на своего пользователя/группу, владеющую experience, дождитесь модерации.
3. Впишите `asset = "rbxassetid://<id>"` для трассы в `src/shared/Config/Sounds.luau`.
   Пока `asset = ""`, трасса **без звука** (никаких заменителей).

Open Cloud: `POST /assets/v1/assets`, `assetType = Audio`, тип файла `audio/wav`, `creationContext`
вашего пользователя; загрузка требует разрешения на папку в Studio Assistant → MCP Permissions.
Лимит Roblox: 10 загрузок в месяц без верификации личности, 100 с верификацией.

Громкость в игре регулируется ползунком «Звуки» (`SoundGroup` `Sfx`).
