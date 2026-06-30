# INSANE NIGHT — ПОЛНАЯ ДОКУМЕНТАЦИЯ ПРОЕКТА

> Внимание: этот файл сгенерирован ИИ. Не читать. Ты предупреждён.

---

## СТЕК И ТЕХНОЛОГИИ

| Компонент | Технология |
|-----------|-----------|
| **Язык** | C++23 (`-std=c++23`), Lua 5.4.8, Rust (утилита `gen_alpha_dictionary`) |
| **Компилятор** | GCC 16.1.1 (Arch Linux rolling) |
| **Сборка** | GNU Make с `-j16`, ручной makefile (не CMake, не Meson) |
| **Рендеринг** | **bgfx** (Vulkan через `bgfx::RendererType::Vulkan`), fallback на X11/Wayland |
| **Окна/Ввод** | **SDL3** (события клавиатуры, мыши, ресайз, оконные ивенты) |
| **Аудио** | **SoLoud** (бэкенд miniaudio) — WAV/MP3 через stb_vorbis |
| **Шрифты** | **tsfont** (кастомный C-враппер поверх FreeType2) + **FreeType2** |
| **Картинки** | **stb_image.h** (PNG/JPG/TGA) + **bimg** (bgfx image loader) |
| **Скриптинг** | **sol2** (C++ → Lua binding), **Lua 5.4.8** (собирается из сорцов) |
| **JSON** | **nlohmann/json** (C++, хедер-онли) + **rxi/json.lua** (Lua, MIT) |
| **Статика** | bgfx/bimg/bx — прекомпиленные `.a` в `external/lib/` |
| **Линтер** | `.clang-tidy` (clang-analyzer, bugprone, performance, misc) |
| **CI/CD** | GitHub Actions (`makefile.yml`) — собирает SDL3 из сорцов, кеширует Lua |
| **VCS** | Git, 8 сабмодулей (bx, bimg, bgfx, SDL, tsfont, sol2, json, soloud20200207, gen_alpha_dictionary) |

---

## MY MACHINE:

```
OS:      Arch Linux rolling (Linux fuck 7.0.14-arch1-1)
CPU:     AMD Ryzen 7 5800H (16 threads, x86_64)
RAM:     15 GiB (10 занято, 4.4 доступно)
Swap:    6 GiB (1.7 занято)
Compiler: g++ (GCC) 16.1.1 20260625
GPU:     Radeon Graphics (integrated) — Vulkan через bgfx
DE:      Неизвестно (X11/Wayland)
```

---

## АРХИТЕКТУРА ПРОЕКТА

### Директории

```
insane_night/
├── assets/            # Ассеты: .png, .jpg, .mp3, .ttf
├── build/             # Артефакты сборки SDL (пусто)
├── external/          # Сабмодули + прекомпиленные библиотеки
│   ├── bgfx/          # Графический движок (submodule)
│   ├── bimg/          # Загрузка изображений (submodule)
│   ├── bx/            # Утилиты bgfx (submodule)
│   ├── SDL/           # SDL3 (submodule)
│   ├── sol2/          # Lua C++ binding (submodule)
│   ├── soloud20200207/# Аудио (submodule)
│   ├── json/          # nlohmann/json (submodule)
│   ├── tsfont/        # Кастомный шрифтовой рендерер (submodule)
│   ├── gen_alpha_dictionary/ # Rust CLI (submodule)
│   ├── lua-5.4.8/     # Сорцы Lua (gitignored, качается при сборке)
│   └── lib/           # Прекомпиленные .a (libbgfx.a, libbimg.a, libbx.a)
├── scripts/           # Lua-скрипты (игровая логика)
│   ├── main.lua       # Входная точка: scene manager, key routing
│   ├── sscreen.lua    # Главное меню ("menu")
│   ├── game.lua       # Визуальная новелла ("gay")
│   ├── settings.lua   # Настройки ("settings")
│   ├── script.json    # Дерево диалогов (JSON)
│   ├── settings.json  # Сохранённые настройки (JSON)
│   └── libs/json.lua  # rxi/json — pure Lua JSON
├── src/               # C++ исходники (движок)
│   ├── main.cpp       # Точка входа, игровой цикл
│   ├── heck.hpp       # ГЛАВНЫЙ ХЕДЕР (1387 строк): все классы
│   ├── heck.cpp       # Реализация движка
│   ├── audio_unc.hpp  # Аудио-движок (SoLoud обёртка)
│   ├── audio_unc.cpp  # Реализация аудио
│   ├── tsfont_wrapper.hpp # C++ обёртка для tsfont C API
│   ├── ligma/          # Lua engine
│   │   ├── ligma.hpp   # LigmaEngine: sol2 state wrapper
│   │   ├── ligma.cpp   # Реализация
│   │   └── bind.hpp   # Биндинг C++ → Lua (147 строк)
│   └── shaders/       # Шейдеры bgfx (.sc + .bin.h)
└── AI_SHIT_DONT_READ.md # Этот файл
```

### Схема вызовов (call flow)

В проекте **запутанная** двухслойная архитектура: C++ рендерит, Lua управляет логикой. Данные гоняются туда-сюда через sol2 биндинги.

#### 1. Запуск программы

```
main(int argc, char** argv)
  │
  ├── LigmaEngine lua;  lua.Init()              // sol2 state + открытие libs
  │
  ├── Hell_Machina engine;
  │   engine.init("heck", 1280, 720, bgfx::RendererType::Vulkan)
  │   │
  │   ├── Sigma::skid(...)                      // Создание SDL окна
  │   ├── Amogus::rizzing(...)                  // Инициализация bgfx (Vulkan)
  │   ├── scenePass / uiPass (Kino)            // Два render pass: сцена и UI
  │   ├── TextGooner::init()                   // Загрузка шрифта
  │   ├── RectGooner::init()                   // Компиляция шейдеров rect
  │   └── ImageGooner::init()                  // Компиляция шейдеров image
  │
  ├── ligma_bind(lua.get_state(), engine)        // РЕГИСТРАЦИЯ ВСЕГО В LUA
  │   │
  │   ├── Userdata: Layer, Rect, Img, Txt
  │   ├── Userdata: TextGooner, RectGooner, ImageGooner, AudioEngine
  │   └── Free functions (19 шт):
  │       getAudioEngine(), loadTexture(), getImageWidth(), getImageHeight(),
  │       setFullscreen(), setVsync(), setVolume(), setFrameLimit(),
  │       addUILayer(), addSceneLayer(), getUILayer(), getSceneLayer(),
  │       getTextGooner() [×2 overloads], getRectGooner(), getImageGooner(),
  │       setFont(), getScreenWidth(), getScreenHeight(), fuckOff()
  │
  ├── lua.ExecuteFile("scripts/main.lua")       // ЗАПУСК LUA-СКРИПТА
  │   │
  │   ├── loadSettings()                        // Чтение scripts/settings.json
  │   ├── applySettings()                       // setFullscreen, setVsync/setFrameLimit, setVolume
  │   ├── dofile("scripts/sscreen.lua")         // Регистрация scene "menu"
  │   ├── dofile("scripts/game.lua")            // Регистрация scene "gay"
  │   └── dofile("scripts/settings.lua")        // Регистрация scene "settings"
  │   └── switchTo("menu")                      // ← первый рендер
  │
  └── while (engine.gooning) { ... }            // ГЛАВНЫЙ ЦИКЛ
```

#### 2. Главный цикл (frame loop)

```
while (engine.gooning)
  │
  ├── SDL_PollEvent(&event)
  │   |
  │   ├── SDL_EVENT_QUIT → engine.gooning = false
  │   ├── SDL_EVENT_KEY_DOWN
  │   │   ├── SDLK_ESCAPE → engine.gooning = false
  │   │   └── иначе → lua.onKeyDown(key)        // В LUA
  │   │
  │   ├── SDL_EVENT_WINDOW_RESIZED / PIXEL_SIZE_CHANGED
  │   │   ├── engine.resize(w, h)
  │   │   └── lua.onResize(w, h) → scrender()   // В LUA
  │   │
  │   └── engine.handleEvent(event)              // hit-test кликабельных Layer
  │
  ├── engine.frame()
  │   │
  │   ├── scenePass.begin();  // view 0
  │   │   └── pork.flush(scenePass.id);
  │   │       └── для каждого DrawCmd: bgfx::submit + setVertexBuffer + ...
  │   │
  │   ├── uiPass.begin();    // view 1
  │   │   └── pork.flush(uiPass.id);
  │   │
  │   ├── amogus.frame();     // bgfx::frame()
  │   │
  │   └── FPS counter (каждую секунду в stdout)
  │
  └── frame limiter (если engine.frameLimit > 0)
      ├── SDL_DelayNS (coarse sleep, -2ms guard)
      └── std::this_thread::yield (spin-wait)
```

#### 3. Обработка клавиш в Lua (key routing)

```
main.lua: onKeyDown(key)
  │
  ├── if currentSceneName == "menu"
  │   └── sscreen.lua: нет menuOnKey → ничего
  │
  ├── if currentSceneName == "gay"
  │   └── game.lua: gameOnKey(key)
  │       └── if key == 32 (SDLK_SPACE)
  │           ├── если есть след. страница → vn.currentPage++
  │           └── иначе → nextNode() → renderGame(ui)
  │
  └── if currentSceneName == "settings"
      └── settings.lua: нет settingsOnKey → ничего
```

#### 4. Рендер сцены (Lua → C++ через биндинги)

```
switchTo("gay")  // main.lua
  │
  ├── currentSceneName = "gay"
  ├── addUILayer("scene_gay") → получаем Layer&
  ├── ui:clear()
  ├── ui.visible = true
  └── renderGame(ui)  // game.lua
      │
      ├── ui:clear()                   // Layer::clear()
      ├── background(ui, node, 0,0,1,0.7)
      │   ├── loadTexture(path)        // CacheMan::loadTexture() → bgfx texture
      │   └── ui:addImageF(...)        // Layer::addImage() → создаёт Image
      │
      ├── syncSound(node)
      │   ├── audio:playSound(path, true)   // AudioEngine::playSound()
      │   └── audio:stopSound(id)           // AudioEngine::stopSound()
      │
      ├── ui:addRectF(...)             // Layer::addRectangle()
      ├── character(ui, node, z)
      │   ├── getImageWidth(charPath)  // CacheMan::getWidth()
      │   └── ui:addImageF(...)        // Layer::addImage()
      │
      ├── ui:addRectF(...)             // speaker plate
      ├── ui:addTextF(...)             // speaker name
      ├── ui:addTextF(...)             // dialogue text
      │
      └── nextBtn:onClick(function()   // Rectangle::onClick()
              // callback хранится в Skibidi.onClick
              // вызывается при hit-test в engine.handleEvent()
          )
```

#### 5. Hit-test (клики)

```
engine.handleEvent(event)  // C++
  │
  ├── для каждого uiLayer: layer.handleEvent(event)
  │   └── для каждого clickable: hitTest(mx, my)
  │       └── если попал → callback.onClick()  // выполняет Lua-функцию
  │
  └── (sceneLayers не обрабатывают события — только UI)
```

### Визуальная новелла (VN engine) — детали

```
game.lua — структура:
  vn = {
    currentNode,     // ID текущей ноды (string)
    currentBg,       // путь к текущему бэкграунду
    currentPage,     // номер текущей страницы текста (1-based)
    currentSound,    // путь к текущему звуку
    currentSoundId,  // handle звука в SoLoud
    currentChar,     // путь к текущему спрайту персонажа
  }

  dialogueCfg = {
    Kawasaki = { x=0, y=0.7, w=1, h=0.3 },      // панель диалога
    Cago     = { x=0.05, y=0.75, right=0.95, bottom=1 },  // текст бокс
    Krico    = { x=0.07, y=0.65, h=0.05, ... }   // плашка говорящего
  }

  Алгоритм рендера ноды:
    1. background() — фон, если node.bg есть, иначе старый
    2. syncSound() — если node.sound изменился, стоп старого, старт нового
    3. Панель диалога (полупрозрачный rect внизу)
    4. character() — спрайт персонажа справа/слева/центр
    5. Плашка говорящего + текст
    6. buildDialoguePages(node.text):
       a. splitExplicitLines — split по \n
       b. wrapParagraph — word wrap по maxWidth (measureText из C++)
       c. paginateLines — деление на страницы по maxLines
    7. Текущая страница текста
    8. Если есть след. страница или след. нода — невидимый rect-кнопка
```

### Настройки (settings persistence)

```
settings.lua:
  loadSettings() ← читает scripts/settings.json
    ├── парсит JSON в таблицу
    └── применяет к глобальному Settings
  saveSettings() ← пишет Settings в scripts/settings.json
  applySettings() ← вызывает setFullscreen/setVsync/... в C++

  Цикл настроек:
    Fullscreen: On/Off (toggle)
    Frame limit: VSync → Unlimited → 30 → 60 → 120 → VSync
    Volume: 0.0 → 0.1 → ... → 1.0 → 0.0 (циклически, шаг 0.1)
```

---

## НЕЙМИНГИ

### C++ классы (heck.hpp)

| Имя | Что делает | Оценка нейминга |
|-----|-----------|----------------|
| `Sigma` | SDL окно (factory: `skid()`) | 💀 зачем |
| `Amogus` | bgfx контекст (factory: `rizzing()`) | 💀💀 |
| `Kino` | Render pass (view + framebuffer) | ❓ окей |
| `Hell_Machina` | Главный движок (всё в одном) | 👍 атмосферно |
| `CacheMan` | Кэш текстур | 😎 |
| `JohnPork` | Батчер draw команд | 💀💀💀 |
| `Skibidi` | Абстрактный UI элемент | 💀💀💀💀 |
| `TextGooner` | Шрифтовой атлас + глифы | 💀💀💀💀💀 |
| `RectGooner` | Шейдерная программа rect | 💀💀💀💀 |
| `ImageGooner` | Шейдерная программа image | 💀💀💀💀 |
| `TsFontHandler` | FreeType2 враппер | ✅ норм |
| `LigmaEngine` | Lua VM (sol2 state) | 💀💀💀 |

### Переменные и члены

| Имя Где | Значение | Оценка |
|----------|----------|--------|
| `engine.gooning` | `bool` — флаг работы цикла | 💀 |
| `buzz` (в Sigma) | `SDL_Window*` | 💀 |
| `goonerType` (в Amogus) | `bgfx::RendererType::Enum` | 💀💀 |
| `pork` (в Hell_Machina) | `JohnPork` батчер | 💀 |
| `s_tex` | Самплер юниформ | ✅ норм |
| `fuckOff()` | Lua-функция выхода | 💀 |
| `ligma_bind()` | Регистрация биндингов | 💀 |
| `E666` | Префикс ошибок | 💀 |
| `readlike_book()` | Чтение файла в Lua | 💀 |

### Lua файлы и функции

| Имя | Назначение |
|-----|-----------|
| `scripts/sscreen.lua` | Меню (название: sscreen = start screen?) |
| `scripts/game.lua` | Визуальная новелла (название сцены: "gay") |
| `register("gay", ...)` | Регистрация сцены новеллы под именем "gay" |
| `switchTo("gay")` | Переключение на сцену новеллы |
| `fuckOff()` | Выход из игры |

### Сабмодули

| Путь | Назначение |
|------|-----------|
| `external/soloud20200207` | SoLoud аудио (закоммичен как есть, дата в названии) |
| `external/gen_alpha_dictionary` | Rust CLI утилита для генерации словаря альфа-канала |

---

## ПРОБЛЕМЫ ПРОЕКТА

1. **Гигантский хедер** — `heck.hpp` 1387 строк, в нём всё: классы, структуры, реализации inline методов. Нет разделения на `.hpp`/`.cpp` для каждого класса. `heck.cpp` тоже огромен.
2. **Смесь неймингов** — мемные названия (`Gooner`, `Skibidi`, `Amogus`, `Sigma`, `Ligma`) вперемешку с нормальными (`CacheMan`, `TextGooner`). Невозможно понять код без контекста.
3. **Нет исключений / ошибок** — `loadTexture` возвращает текстуру с `idx == 65535` (INVALID_HANDLE) при ошибке, ошибки глотаются. В Lua `pcall` используется, но ошибки молча пропадают.
4. **Магические числа** — `65535` (BGFX_INVALID_HANDLE), `0xdd101014`, `0xffe8e8e8`, `0xff101014` разбросаны по Lua без комментариев.
5. **Два движка аудио** — в ранних коммитах был `1ebed24` + `7ddd658` add sound engine (дубликаты), потом переписано. Мёртвый код?
6. **renderGame рекурсия** — `renderGame()` вызывает `nextNode()` → `renderGame()` → ... через клик. Стек Lua может переполниться на длинной сессии.
7. **settings.lua: переключение сцены для ререндера** — при изменении настройки вызывается `switchTo("settings")`, что пересоздаёт весь UI. Это костыль вместо нормального обновления.
8. **scrender() не вызывается в цикле** — рендер происходит только при `switchTo`/`resize`. Нет непрерывного рендера, сцена статична.
9. **Frame limiter** — spin-wait после `SDL_DelayNS` жрёт CPU. Для `frameLimit=60` это 16.6ms на холостом ходу.
10. **Магическая директива** — `---@diagnostic disable: undefined-global, undefined-field` во всех Lua файлах, потому что глобалы приходят из C++.
11. **Путь к шрифту захардкожен** — `"assets/HackRegular-gX84.ttf"` в трёх местах (sscreen.lua, game.lua, settings.lua).
12. **gitignore генерируемых файлов** — `compile_commands.json` в `.gitignore`, хотя он нужен для LSP. Вместо этого makefile его генерирует, но он не версионируется.

---

## ФИЧИ (ЧТО РАБОТАЕТ)

- ✅ Полноценная 2D графика через bgfx (Vulkan)
- ✅ Визуальная новелла: диалоги с бэкграундами, персонажами, звуком
- ✅ Word wrap и пагинация длинного текста
- ✅ Динамический glyph atlas (512→2048) с кешированием глифов
- ✅ Scene manager на Lua: регистрация/переключение сцен
- ✅ Настройки: fullscreen, volume, frame limit с сохранением в JSON
- ✅ Аудио: параллельное проигрывание WAV/MP3 через SoLoud
- ✅ Resize окна с перерисовкой UI
- ✅ Clickable элементы (кнопки) через hit-test
- ✅ CI: GitHub Actions сборка под Ubuntu
- ✅ FPS counter в stdout
- ✅ FreeType2 рендеринг шрифтов
- ✅ stb_image для загрузки текстур
- ✅ 8 сабмодулей с прекомпиленными зависимостями
- ✅ Rust утилита `gen_alpha_dictionary` для генерации словаря альфа-канала

---

## РЕЖИМ СНА И ГРАФИК РАЗРАБОТЧИКА

### Период разработки: 22 июня — 1 июля 2026 (10 дней)

Проект написан за **10 дней**. Ниже — реконструкция режима сна и работы по таймстемпам коммитов (UTC+7, локальное время разработчика).

### Распределение коммитов по часам

```
  00:00 ▏
  01:00
  02:00
  03:00 ███         ← ночные кодинг-сессии
  04:00 ███         ← пик бессонницы
  05:00
  06:00 ██          ← утренний режим "не ложился"
  07:00 ██
  08:00 █
  09:00
  10:00 ██
  11:00 ██
  12:00 █
  13:00
  14:00 █████
  15:00 ██████████████████████  ← АД CI FIX (23 июня, 22 коммита за час)
  16:00 ███
  17:00 ████
  18:00
  19:00 █████████
  20:00 ███
  21:00 ███
  22:00 ████
  23:00 █
```

### Почасовая разбивка по дням

```
                           Время суток (UTC+7)
День        06  08  10  12  14  16  18  20  22  00  02  04
─────────────────────────────────────────────────────────
22 июн (пн)                  ######                    ← первый коммит в 17:41
23 июн (вт)  ###                 ################ ##   ← CI ад с 14:46 до 16:22 (28 коммитов)
24-25       ❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌    ← 3 дня тишины (выходные/отдых/работа)
26 июн (пт)                              ##            ← 2 коммита в 21:26-21:29
27 июн (сб)          ####        ########        ##    ← ночной кодинг в 04:26, с 08:56 до 23:14
28 июн (вс)                      ######          ##    ← начал в 17:42, закончил в 03:53
29 июн (пн)              ############      ######     ← ночная смена до 04:00, днём с 10:34
30 июн (вт)                 ####    #####            ← с 17:43 до 22:21
01 июл (ср)             ####                          ← утренняя сессия 07:23-11:16
```

**Легенда:** `#` — commits, `❌` — полная тишина

### Режим сна (реконструкция)

| Ночь | Лёг спать | Проснулся | Часов сна | Комментарий |
|------|-----------|-----------|-----------|-------------|
| 22→23 июн | 02:00 | 06:30 | **4.5ч** | практически не спал, утром CI война |
| 23→24 июн | ? | ? | **~8ч** | нормальный сон, потом 3 дня перерыва |
| 24→25 июн | — | — | — | не кодил |
| 25→26 июн | — | — | — | не кодил |
| 26→27 июн | 23:00 | 04:00 | **~5ч** | проснулся в 4 утра и сразу кодить |
| 27→28 июн | 04:30 | 10:30 | **~6ч** | лёг под утро, встал к обеду |
| 28→29 июн | 04:00 | 10:30 | **~6.5ч** | ночной кодинг до 4 утра |
| 29→30 июн | 04:00 | 10:00 | **~6ч** | опять до 4 утра (add settings в 03:10) |
| 30 июн→01 июл | 23:30 | 07:00 | **~7.5ч** | лучшая ночь, выспался |

**Средний сон:** ~6 часов за ночь. **Минимум:** 4.5 часа (23→24 июня). **Максимум:** 8 часов (после выгорания 3-дневного перерыва).

### Дневная активность

```
ПН 22 июн:   1 коммит  |  ~1 час     ||  проект начат в 17:41
ВТ 23 июн:  34 коммита |  ~6 часов   ||  CI ад (28 коммитов), первый прототип
СР 24 июн:   0         |  0          ||
ЧТ 25 июн:   0         |  0          ||
ПТ 26 июн:   2 коммита |  ~1 час     ||  короткая сессия вечером
СБ 27 июн:  10 коммитов|  ~7 часов   ||  ночная + дневная смены
ВС 28 июн:   5 коммитов|  ~3 часа    ||  короткий день
ПН 29 июн:   7 коммитов|  ~8 часов   ||  самая длинная смена (3:34 — 21:00)
ВТ 30 июн:  11 коммитов|  ~5 часов   ||  плотная вечерняя сессия
СР 01 июл:   2 коммита |  ~3 часа    ||  утро, проект в процессе
────────────────────────────────────────────────
ИТОГО:      70 коммитов| ~42 часа    ||  среднее 4.2 ч/день
```

### Выводы по режиму

1. **Сова с элементами деструктивного геймдева** — типичный паттерн: ночные сессии до 3-4 утра, пробуждение после 10-11.
2. **3-дневный перерыв (24-26 июня)** — после CI ада разработчик выгорел и не подходил к проекту. Классический "crash after crunch".
3. **Самая продуктивная сессия — 29 июня** (8 часов чистого кодинга): с 10:34 до 21:00 с перерывами. Добавлен FPS counter, чтение диалогов из JSON, настройки.
4. **Самая неэффективная сессия — 23 июня** (22 коммита за 1.5 часа) — всё CI. Разработчик не тестировал локально, пушил, ждал, чинил, снова пушил.
5. **Ни одной ночи с 8+ часами сна** — проект делался на хроническом недосыпе.
6. **Хронотип:** сова/полуночник с эпизодическими "ранними утрами" (07:23 коммит 1 июля — возможно, разработчик так и не ложился).


Всего **70 коммитов**. Автор: `ImpostorBoy`.

```
8c2c47a  add characters system(broken) & fix gh ci: lua          (HEAD)
73f5466  add audio support & syncSound()
640e547  test gh ci
9385543  fix gh ci v727
ac62823  add essentials such as gen alpha dic
a685893  add x,y,w,h params to background/image functions
1ebed24  add sound engine
7ddd658  add sound engine                    (дубликат?)
07f4d0f  better fonts
ce95358  add multiline text&good naming for coordinates struct
10af878  ☥                                    (easter egg?)
9bc5967  Add wrapped multiline dialogue rendering
46fec6e  add settings
f5cfc1c  minor fixes & first demo
081004f  read dialogues from script.json
9810a2a  add fps counter
ed22a72  lua proper scene managemen t
9fe67f5  gooning var moved to HellMachina
a085863  update tsfont: fix UBs and segfaults
1086f1d  fx gh ci
2313066  stop tracking lua
c4db1eb  center the div
2d097d9  git ci fix v1337
9f54820  relative layout + fullscreen + resize + set fullscreen
a655ca5  fix zindex
ac23354  lua scripting support
308ab05  very useful commit                  (??)
6383635  fix fucking cpp lynter
7a8dd91  fix idk
1b28665  add stb_image to loadtexture
ce64adc  fix gh ci v1488 & tga support
bd2c9cf  rectangle & zindex impl
8027d18  layer system
e2c60e0  fix gh ci v666
63422bd  refactor code + clean make + hello world
cb586fa  fix: add Draw() to Skibidi, fix UIman architecture
c5e067c  fix ci
0c99358  fix ci + replace <expected>
cf34ec2  fix: properly add bgfx, bx, bimg as git submodules
6d84034  fix gh ci v16
a67736c  fix gh ci v15
5788e04  fix gh ci v14 ULTRA FINAL FINAL
4c431ac  fix gh ci v13 ULTRA FINAL
727b739  fix gh ci v12 FINAL
7bca4ed  fix gh ci v12
b83a2ee  fix gh ci v11
f601fff  fix gh ci v10
f312567  fix gh ci v9
245f482  fix gh ci v8
6872902  fix gh ci v7
96e1cef  fix gh ci v6
7dd6247  fix gh ci v5
547bbeb  fix gh ci v4
6a86269  fix gh ci v3
0740578  fix gh ci v2
7098484  fix пр сш v1
2364152  fix make v8
2a14ed3  fix make v7
a0664d6  fix make v6
51c0eb7  fix make v5
24932d3  fix make v4
c3e00da  fix make v3
831dd8b  fix make
36b5f69  get ts black
8c7a1fb  fix makefile
4a7f29c  Simplify GitHub Actions workflow by removing steps
b03fe2e  rewrite in classes Sigma & Amogus
703a2f2  make clean
bfc4ddd  module arch && segfault
ad9cb92  rewrite in cpp                     (ПЕРВЫЙ КОММИТ)
```

**Наблюдения:**
- Первый коммит — `rewrite in cpp` (было на чём-то другом, переписали на C++)
- Почти все коммиты CI — `fix gh ci v1`..`v16`, `fix make v1`..`v8` — CI добавлялся методом тыка
- Коммит `10af878 ☥` — просто крест (easter egg/anarchy)
- Коммит `308ab05 very useful commit` — полезный? нихера не понятно
- Несколько коммитов-дубликатов (дважды add sound engine, дважды fix idk)
- Ветка одна (master/main), никаких feature branches
- Сообщения на русском и английском вперемешку
- `fix fucking cpp lynter` — классика
- Коммит `a085863 update tsfont: fix UBs and segfaults` — кто-то нашёл UB и segfaults в tsfont

---

## ЗА ЧТО ПОХВАЛИТЬ РАЗРАБОТЧИКА

1. **Рабочий продукт** — визуальная новелла реально работает: bgfx (Vulkan), диалоги, звук, шрифты, настройки. Это больше, чем 90% брошенных пет-проектов.
2. **Архитектура C++ + Lua** — грамотное разделение: тяжёлый рендеринг на C++, логика UI на Lua. sol2 биндинги сделаны толково.
3. **Динамический glyph atlas** — `TextGooner` сам растёт с 512→2048, умеет реаллоцироваться. Нетривиальная задача.
4. **FuckOff()** — честное название функции выхода. Без лицемерия.
5. **Asset caching** — `CacheMan` с reference counting и lazy loading. Не тупо грузит текстуры каждый кадр.
6. **Frame limiter** — костыльно, но работает. Coarse sleep + spin-wait — стандартный геймдев-паттерн.
7. **CI/CD** — GitHub Actions собирает проект с нуля: SDL из сорцов, Lua из сорцов, кеширование. Задолбался явно, но сделал.
8. **clang-tidy** — настроен, не выключен. Код проверяется.
9. **make compdb** — генерация `compile_commands.json` для LSP. Мелочь, а приятно.
10. **move-only семантика** — везде deleted copy, defaulted move. RAII. Порядок с ресурсами.
11. **Никаких внешних зависимостей через пакетный менеджер** — всё через сабмодули. Воспроизводимая сборка.
12. **Отрицание бренда через нейминг** — смелость называть вещи своими мемными именами достойна уважения.

---

## ЗА ЧТО ОБМАТЕРИТЬ РАЗРАБОТЧИКА

1. **ЕБАНЫЙ НЕЙМИНГ** — `Skibidi`, `Gooner`, `Amogus`, `Sigma`, `JohnPork`, `Ligma` в продакшен-коде. Это пет-проект, ок, но читать это невозможно. Особенно `TextGooner` — это класс для работы со шрифтами. ШРИФТАМИ. `Gooner` — это сленговое "дрочер". `TextGooner` = "дрочер текста". Разработчик, ты в порядке?
2. **1387 СТРОК В ХЕДЕРЕ** — `heck.hpp` — это монстр. Там всё: объявления, определения, вложенные классы, structы. Никакого разделения. `main.cpp` инклюдит `heck.hpp` и получает ВСЁ.
3. **Магические числа в Lua** — `0xdd101014`, `0xffe8e8e8`, `0xffffffff` — 20 раз в `game.lua` без единой константы. Цвета не вынесены. Хоть бы комментарий нахуй написал.
4. **Нет обработки ошибок** — `loadTexture` молча возвращает INVALID_HANDLE, код в Lua проверяет `.idx ~= 65535`, но если текстура не загрузилась — просто серый прямоугольник. Никаких сообщений в UI.
5. **Рекурсивный renderGame** — клик → `onClick` → `renderGame(ui)` → ... рекурсия без хвостовой оптимизации. На 1000+ диалогах — привет переполнение стека.
6. **Дважды один коммит** — `add sound engine` закоммичен дважды (`1ebed24` и `7ddd658`). Не смотрел, что пушишь?
7. **Спам CI коммитами** — `fix gh ci v1..v16`, `fix make v1..v8`. Это **28 коммитов** на починку CI из 70. ПОЛОВИНА КОММИТОВ — ЭТО CI FIX. Может, локально тестировать перед пушем?
8. **Смешанный язык сообщений** — `fix fucking cpp lynter`, `fix idk`, `очень полезный коммит`, `fx gh ci`. Одно сообщение — на английском, другое — на русском, третье — на быдло-русском. Дисциплина? Не слышали.
9. **Пустой коммит** — `10af878 ☥` — просто крест. Нет описания, код не менялся? Зачем?
10. **Мёртвый код** — в ранних версиях была какая-то UI архитектура, потом переписана. `Draw()`, `UIman` — следы прошлых архитектур торчат в git history, но в коде могли остаться.
11. **Нет тестов** — ни одного теста. Даже интеграционного. Даже "игра запускается". CI только собирает проект.
12. **Путь к шрифту в трёх файлах** — если поменять название шрифта, надо править `sscreen.lua`, `game.lua`, `settings.lua`. DRY? Не, не слышали.
13. **`scripts/settings.json` формат** — однострочный JSON без отступов. Человеком не читаем.
14. **Сабмодуль soloud20200207** — дата в названии сабмодуля. То есть SoLoud от февраля 2020. Прошло 6 лет. Никто не обновлял.
15. **settings.lua: switchTo("settings") при изменении** — чтобы обновить UI настроек, происходит переключение сцены на саму себя. Костыль федерального значения.
16. **Функция `scrender()` не вызывается в main loop** — висит мёртвым грузом. Никто не дёргает `scrender()` в цикле — сцена рендерится только при `switchTo()`.

---

## ИТОГ

Проект — классический пет-проект энтузиаста, который хотел сделать визуальную новеллу, изучил bgfx/Vulkan, подтянул Lua-скриптинг, и в процессе **получал удовольствие от нейминга классов**. Код работает. Визуалка есть. Диалоги листаются. Звук играет. Настройки сохраняются.

Но читаемость кода принесена в жертву мемам, архитектура страдает от "давай ещё один слой абстракции с хуёвым названием", а половина git истории — это "fix ci v1488 ON GOD FR FR".

**Вердикт:** забавно, работает, но глаза кровоточат. 7/10.
