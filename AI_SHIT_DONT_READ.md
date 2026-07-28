
# INSANE NIGHT — v2 ТОТАЛЬНЫЙ КОД-РЕВЬЮ

> Сгенерирован ИИ + доработан человеком. Не читать. Ты предупреждён.
> Обновлён 28 июл 2026 — тотальный код-ревью C++ + Lua: 3 critical, 7 high, ~15 medium/low багов

---

## СТЕК

| Компонент | Технология |
|-----------|-----------|
| **Языки** | C++23 (`-std=c++23`), Lua 5.4.8, Rust (gen_alpha_dictionary — мёртвый) |
| **Сборка** | CMake 3.20+ + Ninja, GCC 16.1.1 (локально) / Clang (CI) |
| **Рендеринг** | bgfx (OpenGL бэкенд) + bimg + stb_image.h |
| **Окна/Ввод** | SDL3 (release-3.4.0-1034, предрелиз) |
| **Аудио** | SoLoud 20200207 (miniaudio бэкенд, качается CI-ом) |
| **Шрифты** | tsfont (кастомный форк ImpostorBoy228/tsfont) + FreeType2 |
| **Скриптинг** | sol2 (C++→Lua binding) + Lua 5.4.8 (из сорцов) |
| **JSON** | nlohmann/json (C++) + rxi/json.lua |
| **Статика** | bgfx/bimg/bx — прекомпиленные .a в `external/lib/` |
| **Линтер** | .clang-tidy (clang-analyzer, bugprone, performance, misc, 81 правило) |
| **CI/CD** | GitHub Actions (Ubuntu, Clang, Release, 4 уровня кеша) |
| **VCS** | Git, 8 сабмодулей. soloud20200207 и lua-5.4.8 качаются CI-ом |

---

## АРХИТЕКТУРА

```
main()
  ├── LigmaEngine lua; lua.Init()          // sol2 state + libs
  ├── Hell_Machina engine.init()           // SDL + bgfx + шейдеры + шрифт + аудио
  │   ├── Sigma::skid()                    // SDL3 окно (RESIZABLE)
  │   ├── Amogus::rizzing()                // bgfx init (OpenGL, Wayland→X11 fallback)
  │   ├── scenePass (view 0) + uiPass (view 1) — ortho, Sequential
  │   ├── TextGooner::init()               // дефолтный шрифт (/usr/share/fonts/...)
  │   ├── RectGooner / ImageGooner / AudioEngine::init()
  │
  ├── preloadTextures("assets")            // std::async на каждый файл
  ├── preloadSounds("assets")              // загрузка всех WAV/MP3/OGG
  ├── ligma_bind(lua, engine)               // 8 usertypes + 19 free functions в Lua
  ├── lua.ExecuteFile("scripts/main.lua")  // загрузка сцен
  │   ├── dofile("sscreen.lua")            // регистрация "menu"
  │   ├── dofile("game.lua")               // регистрация "gay" (визуальная новелла)
  │   ├── dofile("settings.lua")           // регистрация "settings"
  │   └── switchTo("menu")
  │
  └── while (engine.gooning)               // ГЛАВНЫЙ ЦИКЛ
        ├── SDL_PollEvent → switch/case
        │   ├── QUIT/CLOSE_REQUESTED → gooning = false
        │   ├── KEY_DOWN (ESC → exit, иначе → lua.onKeyDown)
        │   ├── FOCUS_GAINED/LOST/MINIMIZED/RESTORED → windowActive
        │   ├── RESIZED → engine.resize() + lua.onResize() → scrender()
        │   └── engine.handleEvent(event)  // hit-test кликабельных Layer
        │
        ├── if (windowActive) engine.frame()
        │   ├── scenePass.begin() → layer.collect(pork) → pork.flush(scenePass.id)
        │   ├── uiPass.begin() → layer.collect(pork) → pork.flush(uiPass.id)
        │   └── bgfx::frame()
        │   else SDL_DelayNS(50ms)
        │
        ├── lua.onFrame(dt)
        └── frame limiter (coarse SDL_DelayNS + spin-wait)
```

**Рендер:** двухпроходный (scene → UI) через `JohnPork` (батчер). Lua-сцены создают `Layer` с `Skibidi`-элементами (Text, Rectangle, Image). Hit-test в `engine.handleEvent()`.

---

## СЦЕНЫ (Lua)

| Имя | Файл | Описание |
|-----|------|----------|
| `menu` | `sscreen.lua` | Главное меню: кнопки Let's fucking go / Settings / FUCK GET ME OUT |
| `gay` | `game.lua` | Визуальная новелла: диалоги, спрайты, фоны, звук, выборы |
| `settings` | `settings.lua` | Fullscreen / Frame limit / Volume toggle |

**Механизм сцен:** `register(name, fn)` → `switchTo(name)` → создаёт UILayer "scene_<name>" → вызывает `fn(ui)`.

---

## ДИАЛОГОВАЯ СИСТЕМА (game.lua)

Ноды из `script.json` → `buildDialoguePages()`:
1. `splitExplicitLines` — split по `\n`
2. `wrapParagraph` — word wrap через `measureText()` из C++
3. `paginateLines` — деление на страницы по `maxLines`

Рендер: фон → sound → панель диалога → спрайт персонажа → плашка говорящего → текст → кнопка "далее".

Персонажи: right/left/mid позиция, пропорции через aspect ratio.

---

## НЕЙМИНГИ

| Класс | Назначение | Оценка |
|-------|-----------|--------|
| `Sigma` | SDL окно (factory: `skid()`) | 💀 |
| `Amogus` | bgfx контекст (factory: `rizzing()`) | 💀💀 |
| `Hell_Machina` | Главный движок | 👍 |
| `JohnPork` | Батчер draw команд | 💀💀💀 |
| `Skibidi` | Абстрактный UI элемент | 💀💀💀💀 |
| `TextGooner` | Шрифтовой атлас | 💀💀💀💀💀 |
| `RectGooner` / `ImageGooner` | Шейдерные программы | 💀💀💀💀 |
| `LigmaEngine` | Lua VM (sol2) | 💀💀💀 |
| `CacheMan` | Кэш текстур | ✅ |
| `Kino` | Render pass | ❓ |
| `TsFontHandler` | FreeType2 враппер | ✅ |

**Переменные:** `engine.gooning`, `buzz` (SDL_Window*), `goonerType`, `pork`, `fuckOff()`, `ligma_bind()`, `E666`, `readlike_book()`.
**Lua:** сцена "gay", `switchTo("gay")`, `register("gay", ...)`.
**tsfont:** `cock_measure()`, `cock_kern()`.

---

## ПРОБЛЕМЫ ПРОЕКТА

1. **Гигантский хедер** — `heck.hpp` 1506 строк, всё в одном файле
2. **NOLINTBEGIN на весь хедер** — строки 4 и 1506 отключают статанализ
3. **Смесь неймингов** — невозможно понять код без контекста
4. **Нет обработки ошибок** — `loadTexture` молча возвращает INVALID_HANDLE
5. **Магические числа** — `0xdd101014`, `0xffe8e8e8` без констант
6. **renderGame рекурсия** — переполнение стека + замыкания на устаревший currentPage
7. **settings.lua: switchTo себя** — костыльный ререндер
8. **Frame limiter spin-wait** — жрёт CPU
9. **Путь шрифта в 5 местах** — 4 в Lua + 1 хардкод в heck.cpp:67
10. **BatchKey сравнивает указатели на VertexLayout** — не по содержимому
11. **Прелоад всех текстур/звуков при старте** — включая мёртвый bal.png (1.3MB)
12. **38% коммитов — CI fix** (34 из 90+)
13. **Lua @diagnostic disable** — глобалы из C++ не видны анализатору
14. **Бинарники bgfx tools (80 MB) в git** — shaderc, texturec, libdxcompiler.so
15. **Артефакты сборки/perf/heaptrack в git** — репозиторий раздут

---

## ФИЧИ (ЧТО РАБОТАЕТ)

- ✅ 2D графика через bgfx (OpenGL) с шейдерами (text/rect/image)
- ✅ Динамический glyph atlas (512→2048) с dirty region upload
- ✅ Визуальная новелла: word wrap, пагинация, спрайты, фоны, звук
- ✅ Scene manager на Lua: регистрация/переключение
- ✅ Настройки (fullscreen, volume, frame limit) + JSON persistence
- ✅ Кнопки с hit-test, onClick колбэки в Lua
- ✅ Resize окна + relative layout (addTextF/addRectF/addImageF)
- ✅ Аудио WAV/MP3/OGG через SoLoud с кешированием
- ✅ Сохранение/загрузка (F2/F3) с нотификацией
- ✅ GitHub Actions CI (Ubuntu, Clang, 4 уровня кеша)
- ✅ idle-цикл при потере фокуса (Not Responding fix)
- ✅ Profiler в Lua с замерами между маркерами
- ✅ Move-only семантика, RAII, deleted copy
- ✅ Wayland/X11 автоопределение через SDL3 property API

---

## НАЙДЕННЫЕ БАГИ (C++)

### CRITICAL: Sigma move-assignment double-free
`heck.hpp:1303` — `operator=(&&) = default` копирует `SDL_Window*` без зануления источника. При уничтожении обоих объектов `SDL_DestroyWindow` вызывается дважды. **Double-free crash.**

### CRITICAL: Texture handle leak при перезагрузке
`heck.hpp:115-135` — `textures.emplace()` молча не срабатывает если ключ существует. После bgfx device loss новый Handle теряется, старый (невалидный) остаётся в кэше.

### HIGH: Text::onResize не обновляет хитбокс
`heck.hpp:883-889` — Image/Rectangle вызывают `setHitbox` после ресайза. Text — нет. Текстовые кнопки с неправильной зоной клика после изменения размера окна.

### MEDIUM: Текстура в неправильном формате
`heck.hpp:69-93` — если `bimg::imageConvert` вернул `nullptr`, код проваливается и создаёт текстуру из данных原始ном формате. На выходе — цветной шум.

### MEDIUM: signed integer overflow
`heck.hpp:49,77,87` — `(uint32_t)(w * h * 4)` — умножение в `int` до каста. При >2.1 Гпкс — UB. Для 16384×16384 RGBA (1 Гб) теоретически возможно.

### MEDIUM: sllep() блокирует главный тред
`bind.hpp:128` — `sleep(secs)` из Lua останавливает весь цикл: SDL, bgfx, рендер. Нигде не вызывается, но доступен для выстрела в ногу.

### MEDIUM: Font path хардкодом
`heck.cpp:67` — `/usr/share/fonts/TTF/DejaVuSans.ttf` — Linux-only, без DejaVu молча падает.

### MEDIUM: Атлас тихо отбрасывает глифы
`heck.hpp:748` — при превышении `MAX_ATLAS_SIZE=2048` `growAtlasToFit` возвращает false, глифы не рендерятся без уведомления.

### MEDIUM: preloadTextures thread explosion
`heck.hpp:184-193` — `std::async(std::launch::async)` в цикле по файлам. Каждый вызов создаёт новый OS thread. Для 500 файлов — 500 тредов одновременно. Система может упереться в `RLIMIT_NPROC`. Нет ограничения на количество параллельных загрузок.

### MEDIUM: uploadAtlasRegion построчное копирование
`heck.hpp:711-714` — копирование региона атласа на GPU построчно через `memcpy` в цикле, вместо одного большого `memcpy` на весь прямоугольник. Для маленьких регионов незаметно, для больших — лишние вызовы.

### LOW: uint16 overflow в батчах
`heck.hpp:269` — `uint16_t base = batch->vertexCount`. При >65535 вершин в одном батче — переполнение, сломанная геометрия.

### LOW: JohnPork O(n²) поиск
`heck.hpp:246-256` — линейный поиск по всем батчам на каждый pushGeometry.

### LOW: BatchKey сравнивает указатели на layout
`heck.hpp:229-257` — `b.key.layout == key.layout`. Два одинаковых layout не будут батчиться.

### LOW: getOrCreate не копирует ключ для новых батчей
`heck.hpp:256` — `batches.emplace_back()` с default key. Присваивание только на следующем pushGeometry. Если между reserve и pushGeometry произойдёт реаллокация batches, указатель станет невалидным.

### LOW: Обработка фокуса окна дублируется
`main.cpp:54-80` — `SDL_EVENT_WINDOW_FOCUS_LOST` и `SDL_EVENT_WINDOW_MINIMIZED` делают одно и то же. `RESTORED` и `EXPOSED` тоже. Можно объединить.

---

## НАЙДЕННЫЕ БАГИ (Lua)

### CRITICAL: Бесконечный цикл в sload()/initSload()
`game.lua:401-408` — `while id and id ~= vn.currentNode do id = n.next end`. `script.json` имеет цикл (узел "7" → `"next": "1"`). Если `currentNode` недостижим от `start` или после цикла — **гарантированный зависон**.

### HIGH: Notification timer
`game.lua:370` — `notifTimer = os.time() + 0.5`. `os.time()` возвращает integer, дробь отбрасывается. Нотификация живёт 0 или 1 секунду (когда os.time() переключится), а не полсекунды.

### HIGH: sload() — локальная saved затеняет глобальную
`game.lua:386` — `local saved = data` затеняет глобальную `saved` (строка 15). Работает по совпадению имён. Бомба замедленного действия.

### HIGH: sload() и initSload() — 35 строк копипасты
`game.lua:373-418` и `570-604`. Две почти идентичные функции. Рассинхронизируются при правке одной.

### HIGH: syncSound() — запутанная логика
`game.lua:272-301` — если звук играет (`currentSoundId != 0`) и в узле нет `sound` — молча выходит. Если звук закончился — перезапускает старый. Неочевидное поведение.

### MEDIUM: scrender() на resize перезапускает сцену
`main.lua:41-52` — resize → `onResize()` → `scrender()` → рендер сцены заново. Для "gay" это парсинг script.json, сброс или ginit(). Прогресс теряется.

### MEDIUM: Застревание на последней ноде
`game.lua:551` — `if currentPage < #pages or node.next then`. У ноды "5" нет `next`. После последней страницы — нет кнопки. Выход только F2/F3/закрытие.

### MEDIUM: menuOnKey/settingsOnKey не определены
`main.lua:15,19` — глобальные функции нигде не объявлены. Клавиши в меню/настройках игнорируются.

### MEDIUM: syncSound перезапускает звук после загрузки
`game.lua:272-296` — после sload/initSload `currentSoundId=0`, `currentSound` восстановлен. syncSound видит несоответствие и перезапускает.

### MEDIUM: Гонка currentPage
`game.lua:529,554` — колбэк замыкается на локальную `currentPage`. После множественных renderGame через resize — устаревшее значение.

### LOW: center() определена дважды
`game.lua:446-454` — второе определение перезаписывает первое.

### LOW: ssave() — мёртвый I/O
`game.lua:354-367` — комментарий `-- inflicts segfault(no more)`. Когда-то функция читала state.json, парсила его, добавляла данные, но после segfault'а переписали на запись нового литерала. Старый read остался мёртвым кодом.

### LOW: Копипаста в обработчиках onFrame
`main.cpp:50-52,64-71,93-101` — три раза повторяется паттерн: взять функцию из Lua, проверить `valid()`, вызвать, проверить ошибку. Можно вынести в лямбду/функцию.

---

## WTFs / CODE SMELLS

**Файрвол мемов:**
  `cock_measure()` / `cock_kern()` — функции tsfont. `TextGooner` (gooner = "дрочер"). `LigmaEngine` ("ligma" = lick my...). `Sigma::skid()`, `Amogus::rizzing()`, `JohnPork`, `buzz`, `gooning`.

**Интервью с классами:**
```
JohnPork:       — Я СКЛАДЫВАЮ ВСЁ В КУЧУ И НАДЕЮСЬ НА ЛУЧШЕЕ.
Skibidi:        — Я ничего не делаю. Я просто база.
Sigma:          — Меня зовут Sigma. Метод — skid(). Не задавай вопросов.
Amogus:         — Метод — rizzing(). Иди нахуй.
TextGooner:     — Я ГОНЮСЬ ЗА ТЕКСТОМ. ТЕКСТ — МОЁ ВСЁ.
RectGooner:     — Я рисую квадраты. Это всё. Я счастлив.
CacheMan:       — Дважды загрузить текстуру? ХУЙ ТЕБЕ. Я ЗАКЕШИРОВАЛ.
LigmaEngine:     — Моё имя — каламбур. Ты потратил 5 секунд. Наслаждайся.
Hell_Machina:   — *звуки промышленного оборудования* GOOOOOONING...
```

**Lua имеет доступ ко всей ФС** — библиотеки `io` и `os` открыты. Песочницы нет.

**Две системы координат** — `Kawasaki` использует `(x,y,w,h)`, `Cago` — `(x,y,right,bottom)` в одной структуре.

**Шрифт перезагружается при каждой смене сцены** — `setFont()` в каждой scene fn перечитывает TTF и пересоздаёт атлас.

**Profiler сам себя выключает** — `prof.flush()` делает `enabled = false`. Работает один кадр.

**Ошибки только в консоль** — пользователь без терминала не видит "Lua fuckup", "runtime e" и т.д.

**getTextGooner() может бросить исключение** — `throw std::runtime_error` из C++ в Lua не обрабатывается скриптами.

**30 секунд стыда:** `grep -r "class" src/heck.hpp` → Skibidi, TextGooner, RectGooner, ImageGooner, Sigma, Amogus, Hell_Machina.

**Тайный stash:** `stash@{0}: WIP on main: e789640 fix ci: remove cock_kern dep`. В stash'e код, возвращающий кернинг, выпиленный из-за UB/segfault в tsfont. Ждёт своего часа.

**Doxygen? Нет.** Ни одного doxygen-комментария. Только TODO, инлайн-пояснения и русский мат.

**Два разных шрифта в диалоге:** `g.text` — DejaVuSans (умолчание C++), `g.textSmall` — Hack из ассетов. Имя говорящего — DejaVu, текст — Hack. После `ginit()` (`setFont("Hack", 24)`) g.text переключается на Hack. Не консистентно.

**Сцена называется "gay":** `register("gay", ...)`, `switchTo("gay")`. Разработчик, ты в порядке?

**Профилировщик prof:** вызывается в каждом renderGame: `prof.start()` → mark() → mark() → `prof.flush()`. `flush()` выключает profiler. Работает один кадр за вызов.

**SDL3 из будущего:** Сабмодуль SDL (release-3.4.0-1034). SDL3 официально вышел в 2025, проект на июль 2026 использует предрелизную версию. Смелый ход.

**Алгоритмическая оптимизация:** при добавлении глифов в атлас вычисляется bounding box изменённой области и загружается только она, а не весь атлас. Умно.

**Система сохранения (game.lua):**
- `ssave()` / `sload()` — горячие клавиши F3 / F2
- Пишет/читает `scripts/state.json`: `{ node: "id", choices: [...] }`
- `initSload()` — авто-загрузка при входе в сцену "gay"
- `notif()` — уведомление "Saving..." через слой "savenotif" с авто-скрытием

**Настройки (settings.lua):**
- `loadSettings()` / `saveSettings()` — JSON persistence
- Fullscreen: On/Off toggle
- Frame limit: VSync → Unlimited → 30 → 60 → 120 → VSync (цикл)
- Volume: 0.0 → 0.1 → ... → 1.0 → 0.0 (шаг 0.1, циклически)

---

## GIT ИСТОРИЯ

| Метрика | Значение |
|---------|----------|
| Коммитов | 90+ |
| Авторов | 1.1 (ImpostorBoy 89, ImpostorBoy228 1) |
| Веток | 1 (main), 0 merge commits |
| Stash | 1 (кернинг, выпилен из-за tsfont UB/segfault) |
| CI fix | 34 коммита (38%) |

**Фазы падения разработчика:**

1. **"Я серьёзный"** (22-23 июн) — `rewrite in cpp`, `module arch && segfault`. Нормальный человек.
2. **"CI ломает меня"** (23 июн, 34 коммита) — `fix make v5..v8`, `fix gh ci v2..v16`, `fix gh ci v666/v727/v1337/v1488`. Счётчик пошёл, сатанинские числа.
3. **"Мне всё равно"** (26-29 июн) — `very useful commit`, `fix fucking cpp lynter`, `fix idk`.
4. **"Принятие безумия"** (30 июн-1 июл) — `☥` (пустой крест), `I asked DeekPeek for docs`, `fx gh ci`. Пик.
5. **"Возвращение"** (18-21 июл) — cmake+ninja, preload, profiler, window fix. Выспался. Но "fucking" осталось — шрамы навсегда.

**История soloud:** submodule → `stop tracking soloud` → качается CI-ом с solhsa.com.
**Драма с сохранениями:** `we are fucking removing save slots` — выпилил мульти-слоты, остался один state.json. Следы: мёртвая таблица `local saved`.

### Лог коммитов (избранное)

```
4637471  fix 'window is inactive'
1615b81  fix main.cpp: undefined dt and frameStart
5514eec  cmake build system, texture/sound preload, profiler
ba75cf2  save init, & build cleanup
0c1696e  we are fucking removing save slots
e789640  fix ci: remove cock_kern dep, stub kerning
f13e3be  fix cpp bugs, add kerning & batched rendering
fffa6dd  adding saves p.1
9222249  switch to cmake+ninja & add make dev
313429b  stop tracking soloud
06cec7c  I asked DeekPeek for docs
8c2c47a  add characters system(broken) & fix gh ci: lua
73f5466  add audio support & syncSound()
ac62823  add essentials such as gen alpha dic
1ebed24  add sound engine                     (дубликат)
7ddd658  add sound engine                     (дубликат?)
10af878  ☥                                     (пустой крест)
46fec6e  add settings
9810a2a  add fps counter
a085863  update tsfont: fix UBs and segfaults
308ab05  very useful commit                   (???)
6383635  fix fucking cpp lynter
7a8dd91  fix idk
bd2c9cf  rectangle & zindex impl
8027d18  layer system
b03fe2e  rewrite in classes Sigma & Amogus
bfc4ddd  module arch && segfault
ad9cb92  rewrite in cpp                       (ПЕРВЫЙ)
```

---

## РЕЖИМ СНА РАЗРАБОТЧИКА

Проект написан за ~30 дней (22 июн — 21 июл 2026). Первая фаза 10 дней (70 коммитов), 17-дневный перерыв, вторая фаза 4 дня (14 коммитов).

### Распределение коммитов по часам (UTC+7)

```
  00:00 ▏
  03:00 ███         ← ночные кодинг-сессии
  04:00 ███         ← пик бессонницы
  06:00 ██          ← "не ложился"
  10:00 █████       ← сейвы, баги
  12:00 ████████    ← CI вторая волна
  14:00 █████
  15:00 ██████████████████████  ← CI АД (22 коммита за час)
  19:00 █████████   ← кернинг, батчинг
  21:00 ████████    ← profiler, window fix
  22:00 ██████
```

### Режим сна по дням

| Ночь | Сон | Комментарий |
|------|-----|-------------|
| 22→23 июн | **4.5ч** | практически не спал, утром CI война |
| 23→24 июн | **~8ч** | потом 3 дня перерыва |
| 26→27 июн | **~5ч** | проснулся в 4 утра и сразу кодить |
| 27→28 июн | **~6ч** | лёг под утро |
| 28→29 июн | **~6.5ч** | ночной кодинг до 4 утра |
| 29→30 июн | **~6ч** | опять до 4 утра (add settings в 03:10) |
| 30→01 июл | **~7.5ч** | лучшая ночь, выспался |
| 01→18 июл | — | 17 дней перерыва, проект заброшен |
| 18→19 июл | **~8ч** | нормальный сон |
| 19→20 июл | **~9.5ч** | высыпался |
| 20→21 июл | — | не кодил |
| 21→21 июл | **0ч** | не ложился, финальный спринт |

### Дневная активность

```
22 июн:   1 коммит  | проект начат в 17:41
23 июн:  34 коммита | CI ад
27 июн:  10 коммитов| ночная + дневная смены
29 июн:   7 коммитов| самая длинная смена (8ч)
30 июн:  11 коммитов| плотная вечерняя сессия
18 июл:   6 коммитов| cmake+ninja
19 июл:   3 коммита | сейвы, кернинг
21 июл:   5 коммитов| preload, profiler, window fix
────────────────────────────────────────
ИТОГО:    ~45 часов | среднее 2.9 ч/активный день
```

**Средний сон:** ~6ч/ночь. **Минимум:** 0ч (21 июля). **Максимум:** 9.5ч.

**Паттерн:** сова с элементами деструктивного геймдева. После CI ада (23 июня) — 3 дня тишины. Полное выгорание → 17 дней перерыва (проект мог умереть) → возвращение.

---

## СИСТЕМА СБОРКИ (CMake)

`CMakeLists.txt` (112 строк): C++23, C17. Debug: `-O0 -g`, Release: `-O3 -flto -s`.

**Зависимости:**
- FreeType2 (system), SDL3 (pkg-config), ALSA (опционально)
- `tsfont_obj` — OBJECT library из external/tsfont/font_handler.c
- `lua` — статически из external/lua-5.4.8/src/*.c
- `soloud` — статически core + WAV + filters + miniaudio
- `bgfx_ext/bimg_ext/bx_ext` — IMPORTED из precompiled .a

Шейдеры компилируются через `shaderc` (bgfx tools) в `.bin.h`, встраиваются в бинарник через `#include`.

---

## LUA БИНДИНГИ (ligma/bind.hpp, 153 строк)

**Usertypes (8):**
- `Layer` — addText/addTextF/addRectF/addImageF/addClickable/clear/visible
- `Rect` / `Img` / `Txt` — onClick(callback), setHitbox(x,y,w,h)
- `TextGooner` — measureText, getLineHeight
- `RectGooner` / `ImageGooner` — пустые (только передача ссылки)
- `AudioEngine` — playSound, stopSound, stopAllSounds, setVolume
- `TextureHandle` — idx (readonly)

**Free functions (19):**
`getAudioEngine`, `loadTexture`, `getImageWidth/Height`, `setFullscreen`, `setVsync`, `setVolume`, `setFrameLimit`, `addUILayer`, `addSceneLayer`, `getUILayer`, `getSceneLayer`, `getTextGooner` (×2 overloads), `getRectGooner`, `getImageGooner`, `setFont`, `getScreenWidth/Height`, `fuckOff`, `sllep`.

---

## ИНДЕКС БЕЗУМИЯ

| Файл | Уровень | Причина |
|------|---------|---------|
| `src/ligma/bind.hpp` | 🔥🔥🔥🔥🔥 | `fuckOff`, `E666`, `sllep`, `LigmaEngine` |
| `src/heck.hpp` | 🔥🔥🔥🔥🔥 | 1506 строк, `Sigma::skid`, `Amogus::rizzing`, `gooning` |
| `scripts/game.lua` | 🔥🔥🔥🔥 | сцена "gay", `"I cant properly explain this shit"` |
| `scripts/sscreen.lua` | 🔥🔥🔥🔥 | `"Lets fucking go"`, `"FUCK GET ME OUT!!11!"` |
| `external/tsfont/font_handler.c` | 🔥🔥🔥 | `cock_measure`, `cock_kern`, `// so sigma` |
| `src/audio_unc.hpp` | 🔥🔥 | audio unc = uncle? |
| `src/shaders/` | 🔥 | чистые шрифты. Подозрительно |
| `src/main.cpp` | 🔥 | самый нормальный файл |
| `external/gen_alpha_dictionary/` | 🤖 | Rust. Gen Alpha словарь |

**Учёт профаности:** `fuck` — 8, `shit` — 2, `cock_` — 5, `goon*/er/ing` — ~41. 7/10 по быдлокодингу.

---

## АССЕТЫ

| Файл | Размер | Использование |
|------|--------|--------------|
| `osuback.png` | 2.2 MB | Фон сцены 1 (Osu! дерево) |
| `pablo_.mp3` | 2.2 MB | Саундтрек сцены 1 |
| `megalovania.mp3` | 2.4 MB | Саундтрек сцены 4 |
| `background.png` | 280 KB | Фон меню и сцены 5 |
| `sans.jpg` | 36 KB | Фон сцены 4 (адский Санс) |
| `cirno.png` | 184 KB | Спрайт Чирно (Touhou) |
| `sans.png` | 36 KB | Спрайт Санса (Undertale) |
| `bal.png` | 1.3 MB | **НИГДЕ НЕ ИСПОЛЬЗУЕТСЯ** |
| `HackRegular-gX84.ttf` | 376 KB | Шрифт Hack |

**Undertale × Touhou crossover:** сюжет — Undertale-пародия (Санс: "какой прекрасный снаружи денёк... такие дети как ты должны гореть в аду") с неожиданным появлением Чирно из Touhou.

---

## ВНЕШНИЕ ЗАВИСИМОСТИ

| Зависимость | Размер | Тип |
|------------|--------|-----|
| bgfx (static lib) | 13 MB | Прекомпилен в external/lib/ |
| bimg (static lib) | 5.2 MB | Прекомпилен |
| bx (static lib) | 3.4 MB | Прекомпилен |
| shaderc + texturec + libdxcompiler.so | ~80 MB | Бинарники в git! |
| **Итого external tools** | **~80 MB** | Закоммичены в репу |
| **Итого static libs** | **~22 MB** | |

**gen_alpha_dictionary:** Rust CLI утилита от crnicholson. Генерирует словарь сленга Gen Alpha (skibidi, gyatt, fanum tax). Не используется в проекте.

**tsfont:** форк ImpostorBoy228/tsfont. Кастомный C API над FreeType2. Функции: `font_load`, `font_free`, `cock_measure`, `font_fill_glyphs`, `cock_kern`, `free_bitmap_buffer`.

---

## BAL.PNG — ТЕОРИИ ЗАГОВОРА

`assets/bal.png` (1.3 MB, 1920×1080) нигде не загружается. 9 теорий:
1. **Ballin'** — мем "Skibidi dop dop yes yes"
2. **Бал-город** — танцы, но 1920×1080?
3. **Bob Dylan** — easter egg
4. **Опечатка** — должно быть ball.png
5. **Банан** — banana cut off
6. **Balenciaga** — high fashion
7. **Стеганография** — XOR с длиной названий классов
8. **Мета** — чтоб сбить AI с толку
9. **Реалистичная** — забыли удалить

---

## УЧЁТ ПРОФАНОСТИ (grep по src/ + scripts/)

```
"fuck"         —  8: heck.hpp(1), main.cpp(1), bind.hpp(2), sscreen.lua(3), game.lua(1)
"shit"         —  2: game.lua(2)
"cock_"        —  5: heck.hpp(2), tsfont_wrapper(2), game.lua(1)
"goon*/er/ing" — ~41: heck.hpp(~33), main.cpp(3), bind.hpp(1), sscreen.lua(1), game.lua(3)
```

Разработчик матерится в меру. 7/10 по шкале быдлокодинга.

---

## ВЫВОДЫ О РАЗРАБОТЧИКЕ

1. **Новичок в C++/геймдеве** — мемные названия, гигантский хедер, нет тестов
2. **Знает Lua** — скрипты чисто написаны, word wrap, pagination, profiling
3. **Терпеливый** — 34 CI коммита, не бросил проект
4. **Упоротый** — пишет код в 4 утра, нейминг классов — мемы 2023-2024
5. **Фаталист** — коммит с крестом ☥, `fuckOff()`, названия сцен
6. **Не высыпается** — средний сон 6ч, были ночи по 0-4.5ч
7. **Перфекционист** — heaptrack, perf профили, clang-tidy, dirty region в атласе
8. **Одинокий герой** — 0 PR, 0 merge commits, 1 ветка, 1 автор

---

## ЕСЛИ БЫ ЭТО БЫЛ ФИЛЬМ

| Акт | Сюжет |
|-----|-------|
| **Акт I: Надежда** | Разработчик создаёт Sigma и Amogus. Код чистый. Коммиты осмысленные. "rewrite in cpp" — звучит гордо. |
| **Акт II: Падение** | CI ломается 34 раза. `fix gh ci v666`. `fix idk`. Появляются TextGooner, JohnPork, Skibidi. Разработчик кодит в 4 утра. |
| **Акт III: Принятие** | `10af878 ☥`. Пустой коммит с крестом. Разработчик отпустил ситуацию. Теперь он просто кайфует. |
| **Акт IV: Возвращение** | 17 дней тишины. Проект мёртв. Но нет — `switch to cmake`. Код стал чище. Разработчик выспался. |
| **Финальная сцена** | `4637471 fix 'window is inactive'` — 8103 строки. Разработчик фиксит баг, которым сам же и страдал. |
| **Post-credits** | bal.png мигает на экране. Зачем? Никто не знает. |

---

## ИТОГ КОД-РЕВЬЮ

### 3 CRITICAL
- **Бесконечный цикл в sload()** — зависон при загрузке сохранения
- **Text::onResize без хитбокса** — текстовые кнопки не работают после ресайза
- **Sigma move-assignment double-free** — crash при перемещении

### 7 HIGH
- Битый таймер нотификации (0.5s → 0-1s)
- Локальная saved затеняет глобальную
- 35 строк копипасты sload/initSload
- syncSound — запутанная логика
- scrender сбрасывает прогресс при resize
- Зависание на последней ноде
- Утечка TextureHandle при перезагрузке

### ~15 MEDIUM/LOW
- Мёртвый код, гонка currentPage, uint16 overflow
- O(n²) поиск в JohnPork, signed overflow
- sllep() блокирует тред, font path хардкодом
- thread explosion в preloadTextures
- Атлас тихо отбрасывает глифы
- И т.д.

**Вердикт:** забавно, работает, глаза кровоточат. 7/10.
**Срочно:** пофиксить бесконечный цикл в sload() и хитбоксы текста.
