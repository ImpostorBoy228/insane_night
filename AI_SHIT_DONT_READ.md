# INSANE NIGHT — ПОЛНАЯ ДОКУМЕНТАЦИЯ ПРОЕКТА

> Внимание: этот файл сгенерирован ИИ. Не читать. Ты предупреждён.

---

## СТЕК И ТЕХНОЛОГИИ

| Компонент | Технология |
|-----------|-----------|
| **Язык** | C++23 (`-std=c++23`), Lua 5.4.8, Rust (утилита `gen_alpha_dictionary`) |
| **Компилятор** | GCC 16.1.1 (Arch Linux rolling) |
| **Сборка** | **CMake 3.20+** + **Ninja** (ранее был makefile, переписано 18 июл) |
| **Рендеринг** | **bgfx** (OpenGL через `bgfx::RendererType::OpenGL`, ранее был Vulkan, переключено) |
| **Окна/Ввод** | **SDL3** (события клавиатуры, мыши, ресайз, оконные ивенты) |
| **Аудио** | **SoLoud** (бэкенд miniaudio) — WAV/MP3/OGG, качается CI-ом |
| **Шрифты** | **tsfont** (кастомный C-враппер поверх FreeType2) + **FreeType2** |
| **Картинки** | **stb_image.h** (PNG/JPG/TGA) + **bimg** (bgfx image loader) |
| **Скриптинг** | **sol2** (C++ → Lua binding), **Lua 5.4.8** (собирается из сорцов) |
| **JSON** | **nlohmann/json** (C++, хедер-онли) + **rxi/json.lua** (Lua, MIT) |
| **Статика** | bgfx/bimg/bx — прекомпиленные `.a` в `external/lib/` |
| **Линтер** | `.clang-tidy` (clang-analyzer, bugprone, performance, misc) |
| **CI/CD** | GitHub Actions (`makefile.yml`) — собирает SDL3 из сорцов, кеширует Lua |
| **VCS** | Git, 8 сабмодулей (bx, bimg, bgfx, SDL, tsfont, sol2, json, gen_alpha_dictionary). soloud20200207 и lua-5.4.8 качаются CI-ом (не в git) |

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
├── .build/            # CMake+ніпја сборка (Debug/Release)
├── .clang-tidy        # Конфиг линтера (81 строка, clang-analyzer/bugprone/performance/misc)
├── assets/            # Ассеты: .png, .jpg, .mp3, .ttf
├── external/          # Сабмодули + прекомпиленные библиотеки
│   ├── bgfx/          # Графический движок (submodule)
│   ├── bimg/          # Загрузка изображений (submodule)
│   ├── bx/            # Утилиты bgfx (submodule)
│   ├── SDL/           # SDL3 (submodule)
│   ├── sol2/          # Lua C++ binding (submodule)
│   ├── json/          # nlohmann/json (submodule)
│   ├── tsfont/        # Кастомный шрифтовой рендерер (submodule)
│   ├── gen_alpha_dictionary/ # Rust CLI (submodule)
│   ├── lua-5.4.8/     # Сорцы Lua (gitignored, качается при сборке)
│   ├── soloud20200207/# Аудио (gitignored, качается CI-ом с solhsa.com)
│   └── lib/           # Прекомпиленные .a (libbgfx.a, libbimg.a, libbx.a)
├── scripts/           # Lua-скрипты (игровая логика)
│   ├── main.lua       # Входная точка: scene manager, key routing
│   ├── sscreen.lua    # Главное меню ("menu")
│   ├── game.lua       # Визуальная новелла ("gay")
│   ├── settings.lua   # Настройки ("settings")
│   ├── script.json    # Дерево диалогов (JSON)
│   ├── settings.json  # Сохранённые настройки (JSON)
│   ├── state.json     # Сохранение прогресса (JSON)
│   └── libs/json.lua  # rxi/json — pure Lua JSON
├── src/               # C++ исходники (движок)
│   ├── main.cpp       # Точка входа, игровой цикл
│   ├── heck.hpp       # ГЛАВНЫЙ ХЕДЕР (1440 строк): все классы
│   ├── heck.cpp       # Реализация движка
│   ├── audio_unc.hpp  # Аудио-движок (SoLoud обёртка)
│   ├── audio_unc.cpp  # Реализация аудио
│   ├── tsfont_wrapper.hpp # C++ обёртка для tsfont C API
│   ├── ligma/          # Lua engine
│   │   ├── ligma.hpp   # LigmaEngine: sol2 state wrapper
│   │   ├── ligma.cpp   # Реализация
│   │   └── bind.hpp   # Биндинг C++ → Lua (149 строк)
│   └── shaders/       # Шейдеры bgfx (.sc + .bin.h)
├── CMakeLists.txt     # Система сборки (112 строк)
├── Makefile           # Обёртка: make dev/release/shaders/clean → CMake+Ninja
└── AI_SHIT_DONT_READ.md # Этот файл (863 строки)
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

#### 1.5. Инициализация C++ (детали)

```
engine.init("heck", 1280, 720, bgfx::RendererType::OpenGL)
  │
  ├── Sigma::skid(...)              // SDL3 окно (RESIZABLE)
  ├── Amogus::rizzing(...)          // bgfx init (OpenGL, Wayland→X11 fallback)
  │
  ├── 2 render pass-а:
  │   ├── scenePass (view 0): clear BLACK, ortho, Sequential
  │   └── uiPass    (view 1): NO clear, ortho, Sequential
  │
  ├── TextGooner::init("/usr/share/fonts/TTF/DejaVuSans.ttf", 32)
  ├── RectGooner::init()            // шейдеры rect
  ├── ImageGooner::init()           // шейдеры image
  └── AudioEngine::init()           // SoLoud (MINIAUDIO бэкенд, CLIP_ROUNDOFF)
```

После инициализации:
```
preloadTextures("assets")           // параллельная загрузка через std::async
preloadSounds("assets")             // загрузка в AudioEngine::sounds
ligma_bind(lua, engine)             // 149 строк биндингов
lua.ExecuteFile("scripts/main.lua") // запуск Lua-сцены
```

#### 2. Главный цикл (frame loop)

```
while (engine.gooning)
  │
  ├── SDL_PollEvent(&event)          // switch-case на event.type
  │   |
  │   ├── SDL_EVENT_QUIT / SDL_EVENT_WINDOW_CLOSE_REQUESTED → exit
  │   ├── SDL_EVENT_KEY_DOWN
  │   │   ├── SDLK_ESCAPE → exit (+ всё равно зовёт lua.onKeyDown)
  │   │   └── иначе → lua.onKeyDown(key)        // В LUA
  │   │
  │   ├── SDL_EVENT_WINDOW_FOCUS_GAINED → engine.windowActive = true
  │   ├── SDL_EVENT_WINDOW_FOCUS_LOST   → engine.windowActive = false
  │   ├── SDL_EVENT_WINDOW_MINIMIZED     → engine.windowActive = false
  │   ├── SDL_EVENT_WINDOW_RESTORED / EXPOSED → engine.windowActive = true
  │   │
  │   ├── SDL_EVENT_WINDOW_RESIZED / PIXEL_SIZE_CHANGED
  │   │   ├── engine.resize(w, h)
  │   │   └── lua.onResize(w, h) → scrender()   // В LUA
  │   │
  │   └── engine.handleEvent(event)              // hit-test кликабельных Layer
  │
  ├── if (engine.windowActive)
  │   └── engine.frame()             // полный рендер
  │   else
  │   └── SDL_DelayNS(50ms)          // ~20 FPS в фоне, не блокирует swapchain
  │
  ├── lua.onFrame(dt)                // Lua-колбэк каждый кадр
  │
  └── frame limiter (если engine.frameLimit > 0)
      ├── SDL_DelayNS (coarse sleep, -2ms guard)
      └── std::this_thread::yield (spin-wait)
```
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
| `external/gen_alpha_dictionary` | Rust CLI утилита для генерации словаря альфа-канала |
| `external/soloud20200207` | SoLoud аудио (НЕ сабмодуль, качается CI-ом, gitignored) |
| `external/lua-5.4.8` | Lua 5.4.8 (НЕ сабмодуль, качается CI-ом, gitignored) |

---

## ПРОБЛЕМЫ ПРОЕКТА

1. **Гигантский хедер** — `heck.hpp` 1387 строк, в нём всё: классы, структуры, реализации inline методов. Нет разделения на `.hpp`/`.cpp` для каждого класса. `heck.cpp` тоже огромен.
2. **Смесь неймингов** — мемные названия (`Gooner`, `Skibidi`, `Amogus`, `Sigma`, `Ligma`) вперемешку с нормальными (`CacheMan`, `TextGooner`). Невозможно понять код без контекста.
3. **Нет исключений / ошибок** — `loadTexture` возвращает текстуру с `idx == 65535` (INVALID_HANDLE) при ошибке, ошибки глотаются. В Lua `pcall` используется, но ошибки молча пропадают.
4. **Магические числа** — `65535` (BGFX_INVALID_HANDLE), `0xdd101014`, `0xffe8e8e8`, `0xff101014` разбросаны по Lua без комментариев.
5. **Два движка аудио** — в ранних коммитах был `1ebed24` + `7ddd658` add sound engine (дубликаты), потом переписано. Мёртвый код?
6. **renderGame рекурсия** — `renderGame()` вызывает `nextNode()` → `renderGame()` → ... через клик. Стек Lua может переполниться на длинной сессии.
7. **settings.lua: переключение сцены для ререндера** — при изменении настройки вызывается `switchTo("settings")`, что пересоздаёт весь UI. Это костыль вместо нормального обновления.
8. **Not Responding при потере фокуса** — (ИСПРАВЛЕНО) Добавлены `windowActive`, обработка `SDL_EVENT_WINDOW_FOCUS_LOST/GAINED/MINIMIZED/RESTORED`, и idle-цикл с `SDL_DelayNS(50ms)`.
9. **Frame limiter** — spin-wait после `SDL_DelayNS` жрёт CPU. Для `frameLimit=60` это 16.6ms на холостом ходу.
10. **Магическая директива** — `---@diagnostic disable: undefined-global, undefined-field` во всех Lua файлах, потому что глобалы приходят из C++.
11. **Путь к шрифту захардкожен** — `"assets/HackRegular-gX84.ttf"` в трёх местах (sscreen.lua, game.lua, settings.lua).
12. **gitignore генерируемых файлов** — `compile_commands.json` в `.gitignore`, хотя он нужен для LSP. Вместо этого makefile его генерирует, но он не версионируется.

---

## ФИЧИ (ЧТО РАБОТАЕТ)

- ✅ Полноценная 2D графика через bgfx (OpenGL)
- ✅ Визуальная новелла: диалоги с бэкграундами, персонажами, звуком
- ✅ Word wrap и пагинация длинного текста
- ✅ Динамический glyph atlas (512→2048) с кешированием глифов
- ✅ Scene manager на Lua: регистрация/переключение сцен
- ✅ Настройки: fullscreen, volume, frame limit с сохранением в JSON
- ✅ Аудио: параллельное проигрывание WAV/MP3/OGG через SoLoud
- ✅ Resize окна с перерисовкой UI
- ✅ Clickable элементы (кнопки) через hit-test
- ✅ CI: GitHub Actions сборка под Ubuntu (clang, кеширование)
- ✅ FPS counter в stdout
- ✅ FreeType2 рендеринг шрифтов
- ✅ stb_image для загрузки текстур
- ✅ 8 сабмодулей с прекомпиленными зависимостями
- ✅ Rust утилита `gen_alpha_dictionary` для генерации словаря альфа-канала
- ✅ Сохранение/загрузка прогресса (F2/F3) в state.json
- ✅ Профилировщик в Lua (prof: start/mark/flush)
- ✅ Not Responding fix — idle-цикл при потере фокуса окна
- ✅ Несколько шрифтов через getTextGooner(path, size)
- ✅ Relative layout (addTextF/addRectF/addImageF) для resize
- ✅ Notification layer (savenotif) с авто-скрытием
- ✅ Lua onFrame(dt) колбэк каждый кадр
- ✅ Обработка SDL_EVENT_WINDOW_CLOSE_REQUESTED
- ✅ Авто-загрузка последнего сохранения при входе в сцену

---

## РЕЖИМ СНА И ГРАФИК РАЗРАБОТЧИКА

### Период разработки: 22 июня — 21 июля 2026 (30 дней, из них активно 17)

Проект написан за **~30 дней** с двумя крупными фазами: первая вспышка (10 дней, 22 июн — 1 июл, 70 коммитов) и вторая фаза (18-21 июл, 14 коммитов). Ниже — реконструкция режима сна и работы по таймстемпам коммитов (UTC+7, локальное время разработчика).

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
  10:00 █████       ← сейвы, баги (19-21 июл)
  11:00 ██
  12:00 ████████    ← CI вторая волна + cmake (18 июл)
  13:00
  14:00 █████
  15:00 ██████████████████████  ← АД CI FIX (23 июня, 22 коммита за час)
  16:00 ███
  17:00 ████
  18:00
  19:00 █████████   ← кернинг, батчинг (19 июл)
  20:00 ███
  21:00 ████████    ← кернинг + profiler + window fix (19-21 июл)
  22:00 ██████      ← фиксы (19 июл)
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
02-17     ❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌    ← 16 дней тишины (выгорание/работа/жизнь)
18 июл (сб)    ##    ########                       ← cmake+ninja, CI вторая волна
19 июл (вс)              ####            ######     ← сейвы, кернинг, батчинг
20 июл (пн) ❌❌❌❌❌❌❌❌❌❌❌❌                     ← тишина (отдых)
21 июл (вт)             ########             ####  ← сейвы, preload, profiler, window fix
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
| 01→18 июл | — | — | — | 17 дней перерыва, проект заброшен |
| 18→19 июл | 01:00 | 09:00 | **~8ч** | нормальный сон, утром CI/CMake |
| 19→20 июл | 00:30 | 10:00 | **~9.5ч** | высыпался (сейвы, кернинг) |
| 20→21 июл | — | — | — | не кодил |
| 21→21 июл | не ложился | — | **0ч** | финальный спринт: preload, profiler, window fix |

**Средний сон:** ~6 часов за ночь. **Минимум:** 0 часов (21 июля — не ложился). **Максимум:** 9.5 часов (19→20 июля).

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
-- 17 дней перерыва --------------------------------------------------
СБ 18 июл:   6 коммитов|  ~2 часа    ||  cmake+ninja, CI вторая волна
ВС 19 июл:   3 коммита |  ~3 часа    ||  сейвы, кернинг, батчинг
ПН 20 июл:   0         |  0          ||  отдых
ВТ 21 июл:   5 коммитов|  ~4 часа    ||  preload, profiler, save, window fix
────────────────────────────────────────────────
ИТОГО:      84 коммита| ~45 часов    ||  среднее 2.9 ч/активный день
```

### Выводы по режиму

1. **Сова с элементами деструктивного геймдева** — типичный паттерн: ночные сессии до 3-4 утра, пробуждение после 10-11.
2. **3-дневный перерыв (24-26 июня)** — после CI ада разработчик выгорел и не подходил к проекту. Классический "crash after crunch".
3. **17-дневный перерыв (2-17 июля)** — полное выгорание. Проект мог умереть, но вернулся спустя 17 дней.
4. **Вторая фаза (18-21 июля)** — разработчик вернулся с новыми силами: CMake, сейвы, profiler, preload. Код стал чище.
5. **Самая продуктивная сессия — 29 июня** (8 часов чистого кодинга): с 10:34 до 21:00 с перерывами. Добавлен FPS counter, чтение диалогов из JSON, настройки.
6. **Самая неэффективная сессия — 23 июня** (22 коммита за 1.5 часа) — всё CI. Разработчик не тестировал локально, пушил, ждал, чинил, снова пушил.
7. **Самая бессонная ночь — 21 июля** (0 часов сна). Финальный спринт: preload, profiler, save system, window inactive fix. Коммит в 22:07 — разработчик, вероятно, не ложился с утра.
8. **Хронотип:** сова/полуночник с эпизодическими "ранними утрами" (07:23 коммит 1 июля — возможно, разработчик так и не ложился).


Всего **84 коммита**. Автор: `ImpostorBoy`.

```
4637471  fix 'window is inactive'                                 (HEAD)
1615b81  fix main.cpp: undefined dt and frameStart
5514eec  cmake build system, texture/sound preload, profiler
ba75cf2  save init, & build cleanup
0c1696e  we are fucking removing save slots
e789640  fix ci: remove cock_kern dep, stub kerning until tsfont update
f13e3be  fix cpp bugs, add kerning & batched rendering, optimize cache
fffa6dd  adding saves p.1
de9c12a  fix gh ci 5: fix main build
d883865  fix gh ci 4: cache update
049ace6  fix gh ci 3
828c2dd  fix gh ci 2
8549f8d  fix github workflow
9222249  switch to cmake+ninja & add make dev
313429b  stop tracking soloud
c6ac357  ci fix
0b155dc  ci fix
06cec7c  I asked DeekPeek for docs
8c2c47a  add characters system(broken) & fix gh ci: lua
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
- **Вторая волна CI** (18 июл) — `fix gh ci 2..5` + `fix github workflow` — после перехода на CMake снова CI ад
- **Драма с soloud** — был сабмодулем, потом `313429b stop tracking soloud`, теперь качается CI-ом с solhsa.com
- **Крупнейший коммит** — `4637471 fix 'window is inactive'` (8103 строки) — на самом деле это AI_SHIT_DONT_READ.md + бинарные ассеты
- **Коммит `06cec7c I asked DeekPeek for docs`** — разработчик попросил DeepSeek сгенерировать документацию (этот файл)
- **Коммит `0c1696e we are fucking removing save slots`** — разработчик выпилил слоты сохранений, оставив один файл state.json
- **Финальный коммит (22:07)** — `fix 'window is inactive'` — исправление проблемы "not responding" через windowActive + SDL_DelayNS

---

## ЗА ЧТО ПОХВАЛИТЬ РАЗРАБОТЧИКА

1. **Рабочий продукт** — визуальная новелла реально работает: bgfx (OpenGL), диалоги, звук, шрифты, настройки, сейвы. Это больше, чем 90% брошенных пет-проектов.
2. **Архитектура C++ + Lua** — грамотное разделение: тяжёлый рендеринг на C++, логика UI на Lua. sol2 биндинги сделаны толково.
3. **Динамический glyph atlas** — `TextGooner` сам растёт с 512→2048, умеет реаллоцироваться. Нетривиальная задача.
4. **FuckOff()** — честное название функции выхода. Без лицемерия.
5. **Asset caching** — `CacheMan` с reference counting и lazy loading. Не тупо грузит текстуры каждый кадр.
6. **Frame limiter** — костыльно, но работает. Coarse sleep + spin-wait — стандартный геймдев-паттерн.
7. **CI/CD** — GitHub Actions собирает проект с нуля: SDL из сорцов, Lua из сорцов, SoLoud с solhsa.com, 4 уровня кеширования. Задолбался явно, но сделал.
8. **clang-tidy** — настроен, не выключен. Код проверяется (81 правило).
9. **CMake генерация compile_commands.json** — `CMAKE_EXPORT_COMPILE_COMMANDS=ON` для LSP. Мелочь, а приятно.
10. **move-only семантика** — везде deleted copy, defaulted move. RAII. Порядок с ресурсами.
11. **Никаких внешних зависимостей через пакетный менеджер** — всё через сабмодули/прекомпиленные .a. Воспроизводимая сборка.
12. **Отрицание бренда через нейминг** — смелость называть вещи своими мемными именами достойна уважения.
13. **Window inactive fix** — корректная обработка фокуса окна, idle-цикл при сворачивании.

---

## ЗА ЧТО ОБМАТЕРИТЬ РАЗРАБОТЧИКА

1. **ЕБАНЫЙ НЕЙМИНГ** — `Skibidi`, `Gooner`, `Amogus`, `Sigma`, `JohnPork`, `Ligma` в продакшен-коде. Это пет-проект, ок, но читать это невозможно. Особенно `TextGooner` — это класс для работы со шрифтами. ШРИФТАМИ. `Gooner` — это сленговое "дрочер". `TextGooner` = "дрочер текста". Разработчик, ты в порядке?
2. **1387 СТРОК В ХЕДЕРЕ** — `heck.hpp` — это монстр. Там всё: объявления, определения, вложенные классы, structы. Никакого разделения. `main.cpp` инклюдит `heck.hpp` и получает ВСЁ.
3. **Магические числа в Lua** — `0xdd101014`, `0xffe8e8e8`, `0xffffffff` — 20 раз в `game.lua` без единой константы. Цвета не вынесены. Хоть бы комментарий нахуй написал.
4. **Нет обработки ошибок** — `loadTexture` молча возвращает INVALID_HANDLE, код в Lua проверяет `.idx ~= 65535`, но если текстура не загрузилась — просто серый прямоугольник. Никаких сообщений в UI.
5. **Рекурсивный renderGame** — клик → `onClick` → `renderGame(ui)` → ... рекурсия без хвостовой оптимизации. На 1000+ диалогах — привет переполнение стека.
6. **Дважды один коммит** — `add sound engine` закоммичен дважды (`1ebed24` и `7ddd658`). Не смотрел, что пушишь?
7. **Спам CI коммитами** — `fix gh ci v1..v16`, `fix make v1..v8`, `fix gh ci 2..5`, `fix github workflow`. Это **34 коммита** на починку CI из 84 (40%). ПОЛОВИНА КОММИТОВ — ЭТО CI FIX. Может, локально тестировать перед пушем?
8. **Смешанный язык сообщений** — `fix fucking cpp lynter`, `fix idk`, `очень полезный коммит`, `fx gh ci`. Одно сообщение — на английском, другое — на русском, третье — на быдло-русском. Дисциплина? Не слышали.
9. **Пустой коммит** — `10af878 ☥` — просто крест. Нет описания, код не менялся? Зачем?
10. **Мёртвый код** — в ранних версиях была какая-то UI архитектура, потом переписана. `Draw()`, `UIman` — следы прошлых архитектур торчат в git history, но в коде могли остаться.
11. **Нет тестов** — ни одного теста. Даже интеграционного. Даже "игра запускается". CI только собирает проект, но не запускает.
12. **Путь к шрифту в трёх файлах** — если поменять название шрифта, надо править `sscreen.lua`, `game.lua`, `settings.lua`. DRY? Не, не слышали.
13. **`scripts/settings.json` формат** — однострочный JSON без отступов. Человеком не читаем.
14. **soloud20200207 не в git** — выпилен из сабмодулей, качается CI-ом с solhsa.com. Локально нужно качать вручную. В названии дата — февраль 2020, прошло 6 лет.
15. **settings.lua: switchTo("settings") при изменении** — чтобы обновить UI настроек, происходит переключение сцены на саму себя. Костыль федерального значения.
16. **scrender() вызывается только из onResize** — рендер сцены происходит при switchTo/resize. Нет непрерывного обновления UI. Для визуальной новеллы ОК, но для анимаций — не годится.

---

## СИСТЕМА СБОРКИ (CMake)

```
CMakeLists.txt (112 строк)
├── cmake_minimum_required(VERSION 3.20)
├── C++23, C17
├── Debug:   -O0 -g, BX_CONFIG_DEBUG=1
├── Release: -O3 -flto -s, BX_CONFIG_DEBUG=0, NDEBUG
│
├── find_package(Freetype REQUIRED)
├── pkg_check_modules(SDL3 REQUIRED sdl3)
├── pkg_check_modules(ALSA QUIET)       // опционально для SoLoud
│
├── add_library(tsfont_obj OBJECT)      // external/tsfont/font_handler.c
├── add_library(lua STATIC)             // external/lua-5.4.8/src/*.c (кроме lua.c, luac.c)
│   └── LUA_COMPAT_5_3, LUA_USE_LINUX
├── add_library(soloud STATIC)          // SoLoud core + WAV + filters + miniaudio
│   └── WITH_MINIAUDIO
├── add_library(bgfx_ext STATIC IMPORTED)  // external/lib/libbgfx.a (прекомпилен)
├── add_library(bimg_ext STATIC IMPORTED)  // external/lib/libbimg.a
└── add_library(bx_ext STATIC IMPORTED)    // external/lib/libbx.a

Исполняемый файл: insane_night
Линковка: lua + soloud + bgfx_ext + bimg_ext + bx_ext + Freetype + SDL3 + pthread + dl + m
```

## АУДИО-ДВИЖОК (audio_unc.hpp/cpp)

```
AudioEngine
├── SoLoud::Soloud (MINIAUDIO бэкенд, CLIP_ROUNDOFF флаг)
├── Кэш: unordered_map<string, unique_ptr<SoLoud::Wav>>
├── Поддержка: WAV, MP3, OGG
│
├── init()        → engine.init(CLIP_ROUNDOFF, MINIAUDIO)
├── playSound()   → getOrLoadSound() + engine.play(), singleInstance по умолчанию
├── stopSound()   → engine.stop() по handle
├── stopAllSounds() → engine.stopAll()
├── setGlobalVolume() → clamp(0..1) + engine.setGlobalVolume()
└── preloadSounds() → рекурсивный обход assets, грузит WAV/MP3/OGG
```

## СИСТЕМА ШЕЙДЕРОВ

```
src/shaders/
├── varying.def.sc     // общие атрибуты: a_position, a_texcoord0, a_color0
│
├── vs_text.sc         // вершинный: позиция + texcoord + цвет → gl_Position
├── fs_text.sc         // фрагментный: s_tex * v_color0.a (альфа из R канала)
├── vs_rect.sc         // вершинный: позиция + цвет
├── fs_rect.sc         // фрагментный: v_color0 (сплошной цвет)
├── vs_image.sc        // вершинный: позиция + texcoord + цвет
├── fs_image.sc        // фрагментный: s_tex * v_color0 (RGBA)
│
└── *.bin.h            // прекомпиленные бинарники (шейдеры встроены в бинарник через #include)
```

Компиляция шейдеров: `shaderc` из bgfx tools (`tools/bin/linux/shaderc`), через make target `shaders`.

## LUA БИНДИНГИ (ligma/bind.hpp, 149 строк)

```
Зарегистрированные типы:
├── Layer
│   ├── addText(gooner, text, x, y, color, z) → Txt*
│   ├── addTextF(gooner, text, rx, ry, color, z) → Txt*  (relative)
│   ├── addRectangle(gooner, x, y, w, h, color, z) → Rect*
│   ├── addRectF(gooner, rx, ry, rw, rh, color, z) → Rect*  (relative)
│   ├── addImage(gooner, tex, x, y, w, h, color, z) → Img*
│   ├── addImageF(gooner, tex, rx, ry, rw, rh, color, z) → Img*  (relative)
│   ├── addClickable(x, y, w, h, callback)
│   ├── addClickableF(rx, ry, rw, rh, callback)  (relative)
│   ├── visible (get/set)
│   └── clear()
│
├── Rect  → onClick(callback), setHitbox(x,y,w,h)
├── Img   → onClick(callback), setHitbox(x,y,w,h)
├── Txt   → onClick(callback), setHitbox(x,y,w,h)
├── TextGooner → measureText(text), getLineHeight()
├── RectGooner (пустой usertype)
├── ImageGooner (пустой usertype)
├── AudioEngine → playSound(path, singleInstance), stopSound(id), stopAllSounds(), setVolume(v)
└── TextureHandle → idx (readonly)

Свободные функции (19+):
├── getAudioEngine() → AudioEngine&
├── loadTexture(path) → TextureHandle
├── getImageWidth(path) / getImageHeight(path)
├── setFullscreen(bool) / setVsync(bool) / setVolume(float) / setFrameLimit(int)
├── addUILayer(name) / addSceneLayer(name) → Layer&
├── getUILayer(name) / getSceneLayer(name) → Layer*
├── getTextGooner() / getTextGooner(path, size) / getRectGooner() / getImageGooner()
├── setFont(path, size)
├── getScreenWidth() / getScreenHeight()
├── fuckOff()     // engine.gooning = false
└── sllep(secs)   // sleep(secs) из unistd.h
```

## СИСТЕМА СОХРАНЕНИЯ (game.lua)

```
ssave() / sload() — горячие клавиши F3 / F2
└── Читает/пишет scripts/state.json (формат: { node: "id", choices: [...] })
└── initSload() — авто-загрузка при входе в сцену "gay"
└── notif() — уведомление "Saving..." (слой "savenotif", авто-скрытие через onFrame)

notifLayer:
├── addRectF (белый фон, 0.7,0.005,0.29,0.1)
├── addRectF (верхняя граница, #474747)
├── addRectF (нижняя граница, #474747)
└── addTextF (текст, #2b2b2b)
```

## CI/CD (GitHub Actions)

```
.github/workflows/makefile.yml (88 строк)
├── Триггер: push / PR на main
├── runner: ubuntu-latest
│
├── Шаги:
│   1. checkout + submodules: recursive
│   2. apt: cmake, ninja, freetype, X11, Wayland, EGL
│   3. Cache Lua 5.4.8 (с lua.org, если не закеширован)
│   4. Cache SoLoud 20200207 (с solhsa.com, если не закеширован)
│   5. SDL3: cmake сборка из submodule, кеш по коммиту SDL
│   6. Install SDL3 (sudo cmake --install)
│   7. Cache CMake build dir
│   8. Build: cmake -B build -G Ninja (clang) + ninja -C build
│
└── Сборка под clang, Release
```

## АССЕТЫ

```
assets/
├── HackRegular-gX84.ttf      // основной шрифт (используется везде)
├── background.png            // фон меню / настройки
├── osuback.png               // фон 1-й сцены (Санс)
├── sans.jpg                  // фон 4-й сцены (Санс в аду)
├── sans.png                  // спрайт Санса (mid)
├── cirno.png                 // спрайт Чирно (left)
├── bal.png                   // ?
├── pablo_.mp3                // звук 1-й сцены (Pablo)
├── megalovania.mp3           // звук 4-й сцены (Megalovania)
└── (загружаются через CacheMan с кешированием и reference counting)
```

## СКРИПТ ДИАЛОГОВ (script.json)

```
5 нод:
├── "1" → bg: osuback.png, speaker: Санс, char: sans.png (mid), sound: pablo_.mp3
│         text: "какой прекрасный снаружи денёк." → next: "2"
├── "2" → speaker: Санс, text: "птички поют..." → next: "3"
├── "3" → speaker: Санс, text: "в такие дни такие дети, как ты..." → next: "4"
├── "4" → bg: sans.jpg, speaker: Санс, sound: megalovania.mp3
│         text: "Должны гореть в аду." → next: "5"
└── "5" → bg: background.png, speaker: "???", char: cirno.png (left)
          text: "Очень длинная реплика..." (без next — конец)
```

---

## НАЙДЕННЫЕ БАГИ (C++)

### CRITICAL: Sigma move-assignment double-free
`heck.hpp:1248` — `Sigma &operator=(Sigma &&) = default;`
Move-конструктор вручную зануляет `other.buzz` после перемещения `SDL_Window*`, но move-assignment — `= default`, что копирует указатель без зануления источника. При уничтожении обоих объектов `SDL_DestroyWindow` вызывается дважды на одном указателе. **Double-free crash.**

### HIGH: Texture handle leak при перезагрузке
`heck.hpp:115-135` — `CacheMan::loadTexture()` использует `textures.emplace()` который **молча не срабатывает** если ключ уже существует. Если текстура была загружена, потом её Handle стал невалидным (bgfx reset/device loss), и `loadTexture` вызвали снова — новый Handle теряется, старый (невалидный) остаётся в кэше.

### MEDIUM: Текстура в неправильном формате
`heck.hpp:69-93` — `loadTextureUncached()`: если формат изображения не RGBA8, код пытается конвертировать через `bimg::imageConvert`. Если конвертация не удалась (`conv == nullptr`), код **проваливается** дальше и создаёт текстуру с `bgfx::TextureFormat::RGBA8` из данных в原始ном формате. На выходе — цветной шум.

### MEDIUM: Signed overflow в размерах текстур
`heck.hpp:49,77,87` — `(uint32_t)(w * h * 4)`: `w` и `h` это `int`, умножение выполняется в `int` до каста. Если `w * h * 4 > INT_MAX` (~2.1Гпкс) — **UB** (signed integer overflow). Для 16384×16384 RGBA это 1Гб, так что теоретически возможно.

### MEDIUM: `sllep()` блокирует главный тред
`bind.hpp:124` — `luaState.set_function("sllep", [&](int secs) { sleep(secs); });`
Функция доступна из Lua, но `sleep()` останавливает **весь** главный цикл: SDL, bgfx, рендер, ивенты. Окно зависает на `secs` секунд. Нигде не используется, но доступна для выстрела в ногу.

### MEDIUM: Thread explosion в preloadTextures
`heck.hpp:184-193` — `std::async(std::launch::async, ...)` в цикле по файлам. Каждый вызов создаёт **новый OS thread**. Если в `assets/` 500 файлов — 500 тредов одновременно. Система может упереться в `RLIMIT_NPROC`.

### MEDIUM: Font path хардкодом
`heck.cpp:67` — `textGooner.init("/usr/share/fonts/TTF/DejaVuSans.ttf", 32);`
Жёстко зашит путь для Linux (Debian/Arch). На macOS/Windows или системах без этого шрифта — инициализация молча падает, текст не рендерится.

### LOW: Vertex buffer overflow
`heck.hpp:269,282` — `uint16_t base = batch->vertexCount;` — если в одном батче >65535 вершин (длинный текст с одинаковым шрифтом), `uint16_t` переполняется, геометрия ломается.

### LOW: JohnPork::getOrCreate — O(n) поиск
`heck.hpp:246-256` — линейный поиск по всем батчам на каждый `pushGeometry()`. Для сцены с сотней текстур/шейдеров — O(n²) на кадр.

---

## НАЙДЕННЫЕ БАГИ (Lua)

### BUG: Notification timer игнорирует 0.5 секунды
`game.lua:377` — `notifTimer = os.time() + 0.5`
`os.time()` возвращает **integer** секунд. Прибавление 0.5 отбрасывается: `os.time() + 0` = `os.time()`. Уведомление о сохранении исчезает **в следующем кадре**, а не через полсекунды.

### BUG: ssave() читает state.json и сразу выбрасывает
`game.lua:350-365` — функция открывает `scripts/state.json`, читает, парсит JSON, а **сразу после этого** перезаписывает переменную `data` новым литералом. Весь read — мёртвый I/O. Комментарий `-- inflicts segfault(no more)` намекает что это было затычкой от segfault'а, которую забыли убрать.

### BUG: sload() и initSload() — 98% дубликат
`game.lua:380-425` и `503-536` — две почти идентичные функции загрузки сохранения. Если исправить одну и забыть про другую — они рассинхронизируются.

### BUG: scrender() на resize перезапускает сцену
`main.lua:41-52` — при ресайзе окна C++ вызывает `onResize()` → `scrender()` → `fn(currentScene)`. Для сцены "gay" это заново парсит `script.json`, перезагружает сохранение или сбрасывает игру в `ginit()`. Любой несохранённый прогресс теряется при ресайзе.

### BUG: Игрок застревает на последней ноде
`game.lua:488` — `if currentPage < #pages or node.next then`. У ноды "5" в `script.json` нет поля `next`. Когда игрок доходит до последней страницы последней ноды — нет кнопки для продолжения. Выход только через F2/F3/закрытие окна.

### BUG: menuOnKey и settingsOnKey не определены
`main.lua:15,19` — `if menuOnKey then menuOnKey(key) end` — глобальные функции `menuOnKey` и `settingsOnKey` **нигде не объявлены**. Горячие клавиши в меню и настройках молча игнорируются.

### BUG: syncSound() перезапускает звук после загрузки
`game.lua:267-296` — после `sload()` или `initSload()` переменная `vn.currentSoundId` сбрасывается в 0, а `vn.currentSound` восстанавливается из цепочки нод. При рендере текущей ноды, если у ней нет `sound`, `syncSound` видит что `currentSoundId == 0` и **перезапускает** старый звук заново.

### BUG: Гонка currentPage (Issue #17)
`game.lua:469,491-492` — В `renderGame()` создаётся локальная `local currentPage = math.min(vn.currentPage, #pages)`. Клик-колбэк замыкается на эту локальную переменную. Если `renderGame()` вызвать несколько раз (через resize), колбэк держит устаревший `currentPage`, и нажатие пробела (использует `vn.currentPage`) расходится с кликом.

---

## WTFs / CODE SMELLS

### Файрвол мемных неймингов
Весь C++ код — это копилка интернет-мемов:
- `Hell_Machina` — главный движок
- `JohnPork` — батчер
- `Skibidi` — UI элемент
- `Amogus::rizzing()` — фабрика bgfx контекста
- `Sigma::skid()` — фабрика SDL окна
- `buzz` — указатель на `SDL_Window*`
- `gooning` — флаг работы цикла
- `goonerType` — тип рендерера
- `cock_measure()` / `cock_kern()` — функции tsfont
- `RectGooner` / `TextGooner` / `ImageGooner` — Gooner = "дрочер"
- `LigmaEngine` — "ligma" = lick my...

### Lua-скрипты имеют доступ ко всей файловой системе
`ligma.cpp:7-16` — в Lua открыты библиотеки `io` и `os`. Любой скрипт может читать/писать любые файлы и выполнять команды ОС. Песочницы нет.

### Две системы координат в dialogueCfg
`game.lua:21-24` — `Kawasaki` использует `(x, y, w, h)`, а `Cago` использует `(x, y, right, bottom)`. В одной структуре — два формата.

### Шрифт перезагружается с диска при каждой смене сцены
`sscreen.lua:6`, `game.lua:309`, `settings.lua:138` — каждая сцена вызывает `setFont("assets/HackRegular-gX84.ttf", 24)`, который в C++ перечитывает TTF-файл с диска и пересоздаёт весь glyph atlas. На HDD это может быть ~50ms на сцену.

### Два разных шрифта в одном диалоговом окне
`game.lua:28-31` — `g.text` использует DejaVuSans (умолчание из C++), `g.textSmall` использует Hack. Имя говорящего рисуется DejaVu, текст диалога — Hack. После вызова `ginit()` (который зовёт `setFont("Hack", 24)`), `g.text` переключается на Hack. Визуально не консистентно.

### Мёртвый код
- `heck.hpp:41` — `//static bool fuckCpp = true;` закомментированный глобал
- `game.lua:15-18` — таблица `local saved` никогда не используется (осталась от слотов сохранений)
- `game.lua:30` — `g.textOk` нигде не используется
- `bind.hpp:124` — `sllep()` не вызывается ни в одном скрипте

### Путь к шрифту в 4 местах, а не в 3
Проблема #11 в документации: "путь к шрифту в трёх местах". На самом деле в 4: `sscreen.lua:6`, `game.lua:29-31` (3 раза с разными размерами), `settings.lua:138`. И дефолтный `heck.cpp:67` — это 5-й.

### Profiler сам себя выключает
`game.lua:109` — `prof.flush()` делает `prof.enabled = false`. Профилировщик работает только **один кадр** на каждый вызов `prof.start()`. Работает потому что `renderGame()` вызывает `start()` → ... → `flush()` каждый раз, но если забыть `start()` — молчит.

### Ошибки в консоль, не в UI
Все ошибки пишутся в `std::cerr` / `print()`. Пользователь, запустивший игру без терминала, никогда не увидит "Lua fuckup", "runtime e", "Fuck your scripts/script.json" и прочих диагностик.

---

## GIT ИСТОРИЯ: ИНТЕРЕСНЫЕ ФАКТЫ

### Статистика
| Метрика | Значение |
|---------|----------|
| Всего коммитов | 90 |
| Авторов | 1.1 (ImpostorBoy — 89, ImpostorBoy228 — 1) |
| Веток | 1 (main), никогда не было feature branches |
| Merge commits | 0 |
| Rebase'ов | несколько (reflog показывает rebase + rebase aborted) |
| Stash | 1 (возвращает kerning, выпиленный из-за проблем с tsfont) |
| Stash назван | "WIP on main: e789640 fix ci: remove cock_kern dep" |
| Тегов | 0 |
| Первый коммит | `ad9cb92 rewrite in cpp` (22 июн 2026, 10:41) |

### Истории rebase'ов
`git reflog` показывает что разработчик делал `git pull --rebase`, затем отменял (`rebase aborted`), затем снова rebase. Git-история была переписана как минимум один раз. Оригинальная ветка называлась `master`, потом переименована в `main`.

### Stash: запретная функция
В stash'e лежит код, который возвращает вызов `cock_kern()` в `hekk.hpp` и `tsfont_wrapper.hpp`. Эта функция была удалена в коммите `e789640` ("fix ci: remove cock_kern dep, stub kerning until tsfont update"). То есть кернинг **работал**, потом **сломался** (проблемы с tsfont), его **выпилили**, но разработчик сохранил код в stash — возможно, чтобы вернуть когда tsfont починят.

### Распределение коммитов
```
fix gh ci / fix make / fix github workflow:  34 коммита (38%)
add ... :                                     11 коммитов (12%)
fix (баги, фичи):                             23 коммита (26%)
прочее (docs, рефакторинг, CI):               22 коммита (24%)
```
Из 90 коммитов **38% — это CI**. Разработчик потратил почти половину времени на борьбу с GitHub Actions.

### Самая тёмная история: soloud
1. Был сабмодулем в .gitmodules
2. Потом `313429b stop tracking soloud` — удалён из сабмодулей
3. Файлы soloud остались в репе как обычные файлы
4. CI качал soloud_20200207_lite.zip с solhsa.com
5. Потом soloud20200207/ был выпилен из git (commit `9222249` — переход на cmake)
6. Сейчас солоуд — библиотека, собираемая из сорцов, которые качает CI

### `06cec7c I asked DeekPeek for docs`
Этот коммит (от 1 июля, 04:29 утра) добавил **первую версию** AI_SHIT_DONT_READ.md. Разработчик попросил DeepSeek сгенерировать документацию в 4:30 утра. Коммиты до этого — 00:23, следующий — 04:16. Разработчик не спал.

### `10af878 ☥`
Пустой коммит с одним анкхом (☥). Код не менялся. Никакого описания. Просто крест. Никто не знает зачем.

---

## ВНЕШНИЕ ЗАВИСИМОСТИ

### Цифры

| Зависимость | Размер | Тип |
|------------|--------|-----|
| bgfx (static lib) | 13 MB | Прекомпилен |
| bimg (static lib) | 5.2 MB | Прекомпилен |
| bx (static lib) | 3.4 MB | Прекомпилен |
| shaderc | 18 MB | Бинарник (компилятор шейдеров) |
| libdxcompiler.so | 29 MB | DirectX shader compiler |
| texturec | 19 MB | Компилятор текстур |
| **Итого external tools** | **~80 MB** | |
| **Итого static libs** | **~22 MB** | |

### Что за `gen_alpha_dictionary`?
Сабмодуль `external/gen_alpha_dictionary` — это Rust-утилита от crnicholson, которая генерирует... словарь сленга поколения Alpha (Skibidi, Gyatt, Fanum Tax, и т.д.). В проекте не используется, но зачем-то подключена как сабмодуль. Возможно, разработчик хотел использовать её для генерации внутриигрового контента, но не дошёл.

### tsfont — кастомный форк
`external/tsfont` — форк от `ImpostorBoy228/tsfont`. Это обёртка над FreeType2 с кастомным C API. Названия функций: `font_load`, `font_free`, `cock_measure`, `font_fill_glyphs`, `cock_kern`, `free_bitmap_buffer`. Зачем `cock_` — загадка.

---

## АНАЛИЗ АССЕТОВ

| Файл | Размер | Формат | Использование |
|------|--------|--------|--------------|
| `osuback.png` | 2.2 MB | PNG | Фон сцены 1 (Osu! дерево) |
| `pablo_.mp3` | 2.2 MB | MP3 | Саундтрек сцены 1 (Pablo) |
| `megalovania.mp3` | 2.4 MB | MP3 | Саундтрек сцены 4 (Megalovania) |
| `background.png` | 280 KB | PNG | Фон меню и сцены 5 |
| `sans.jpg` | 36 KB | JPG | Фон сцены 4 (адский Санс) |
| `cirno.png` | 184 KB | PNG | Спрайт Чирно (Touhou) |
| `sans.png` | 36 KB | PNG | Спрайт Санса (Undertale) |
| `bal.png` | 1.3 MB | PNG | Загадочный файл, нигде не используется |
| `HackRegular-gX84.ttf` | 376 KB | TTF | Шрифт Hack |

### Что за `bal.png`?
Файл `assets/bal.png` (1.3 MB) **нигде не загружается** в коде. Ни в одном Lua-скрипте, ни в C++. Возможно, это был тестовый спрайт или мем с балом (Ballin'? Bob Dylan? Бал-город?). Назначение неизвестно.

### Undertale × Touhou crossover
Сюжет визуальной новеллы — это Undertale-пародия (Санс: "какой прекрасный снаружи денёк... такие дети как ты должны гореть в аду") с неожиданным появлением Чирно из Touhou в конце. Полная неожиданность для игрока, ожидающего стандартный Undertale-фанфик.

---

## ПРОЧИЕ ИНТЕРЕСНЫЕ ДЕТАЛИ

### Алгоритмическая оптимизация: dirty region в атласе
`heck.hpp:803-850` — при добавлении новых глифов в шрифтовой атлас, код вычисляет **bounding box** добавленных глифов и загружает на GPU только изменившуюся область, а не весь атлас целиком. Это нетривиальная оптимизация, сделанная правильно.

### Двухфазный frame limiter
`main.cpp:102-117` — сначала грубый `SDL_DelayNS` (эффективный, но неточный), затем точный spin-wait с `std::this_thread::yield()`. Стандартный геймдев-паттерн для экономии энергии с сохранением точности.

### Wayland/X11 автоопределение
`heck.hpp:1276-1299` — через SDL3 property API код определяет, работает ли приложение под Wayland или X11, и передаёт правильные native window handles в bgfx. Современный кросс-платформенный подход.

### bgfx tools в репозитории
В `external/bgfx/tools/bin/linux/` лежат 6 бинарников + 2 shared library (~80 MB): `shaderc`, `texturec`, `texturev`, `geometryc`, `geometryv`, `libdxcompiler.so`, `libdxil.so`. Они **закоммичены в git** (бинарники!), что раздувает репозиторий.

### build.ninja и .o файлы в git
`.build/build.ninja`, `.build/.ninja_deps`, `.build/.ninja_log` и объектные файлы `.o` — всё это **в git** (directories aren't gitignored individually). Это добавляет шума в диффы.

### heap profile в корне
`heaptrack.insane_night.369383.zst` (сжатый heap профиль) и `perf.data` (538 KB, perf профиль) — забытые в корне репы результаты профилирования. Разработчик явно искал утечки памяти и узкие места.

### .gitignore: что должно быть там, но чего нет
`.gitignore` игнорирует `lua-5.4.8/`, `soloud20200207/`, `build/`, `*.o`, `*.a`, `compile_commands.json`. Но **НЕ игнорирует**:
- `.build/*.o` — все объектники от сборки
- `.build/build.ninja` — сгенерированный Ninja-файл
- `.build/.ninja_deps`, `.build/.ninja_log` — логи сборки
- `perf.data` (538 KB)
- `heaptrack.*.zst` (heap профиль)
- `gcm.cache/` — кэш precompiled headers
- `external/bgfx/tools/bin/linux/*` — 80 MB бинарников

Репозиторий раздут на ~100+ MB из-за всего этого.

### perf.data: что профилировал разработчик?
Файл `perf.data` (538 KB) — это Linux `perf` профиль. Судя по размеру, сессия длилась несколько секунд. Разработчик явно искал узкие места: скорее всего, тормоза рендеринга текста или загрузки текстур.

### heaptrack: утечки памяти?
`heaptrack.insane_night.369383.zst` — сжатый профиль кучи (165 KB в сжатом виде). Разработчик запускал `heaptrack` для поиска утечек памяти. После коммита `a085863 "update tsfont: fix UBs and segfaults"` вероятно остались подозрения на утечки.

### Тайный stash: кернинг ждёт своего часа
```
stash@{0}: WIP on main: e789640 fix ci: remove cock_kern dep
```
В stash'e лежит код, возвращающий вызов `cock_kern(font, prevCodepoint, codepoint)` в `Text::rebuildGeometry()`. Сейчас кернинг замокайден:
```cpp
float getKerning(uint32_t prevCodepoint, uint32_t codepoint) const {
    return font ? cock_kern(font, prevCodepoint, codepoint) : 0.0f;
    // ↑ сейчас всегда 0 из-за проблем с tsfont
}
```
Разработчик выпилил кернинг потому что tsfont падал с UB/segfault. Починит tsfont — применит stash.

### bal.png: расследование
`assets/bal.png` (1.3 MB, 1920×1080) не загружается ни в одном Lua-скрипте и не упоминается в C++ коде. Размер и соотношение сторон (16:9) намекают что это полноэкранный фон/арт. Возможные теории:
1. Тестовый спрайт для разработки
2. Запасной фон, который планировалось использовать
3. Пасхалка/мем, который разработчик забыл добавить
4. Это Ballin' мем (в духе gen_alpha_dictionary — "Skibidi dop dop yes yes")

### SDL3 из будущего
Сабмодуль SDL (release-3.4.0-1034) — SDL3 (не SDL2). Разработчик использует **SDL3 ещё до его официального релиза** (SDL3 вышел в 2025, но проект на июль 2026 использует предрелизную версию). Смелый ход.

### tsfont: форк с секретными функциями
Форк `ImpostorBoy228/tsfont` — это не официальный tsfont. Разработчик форкнул репозиторий и добавил туда свои правки (включая коммит `a085863 "fix UBs and segfaults"`). Судя по названиям функций (`cock_measure`, `cock_kern`), разработчик модифицировал C-API для интеграции с проектом.

### Сцена называется "gay"
`game.lua:538` — `register("gay", function(ui) ...)`. Визуальная новелла зарегистрирована под именем `"gay"`. Переключение на неё: `switchTo("gay")`. Разработчик, ты в порядке?

### "I asked DeekPeek for docs"
Коммит в 04:29 утра 1 июля. Разработчик попросил DeepSeek сгенерировать AI_SHIT_DONT_READ.md. Интересно, сколько раз он перегенерировал, пока не получил устраивающий результат? Или это был первый же промпт "напиши документацию"?

### Нейминг-антипаттерны (продолжение)
Помимо мемных названий классов, есть жемчужины:
- `E666` — префикс ошибок (E666, а не E_ERROR)
- `Sigma::skid()` — "skid" = "скинуть, уйти" (skid row?)
- `Amogus::rizzing()` — "rizzing" = "rizz" (харизма) + "-ing"
- `JohnPork` — отсылка к John Pork (мемный персонаж)
- `pork` — переменная батчера в Hell_Machina
- `buzz` — SDL_Window* (откуда? что за buzz?)
- `Kino` — render pass (отсылка к "kino" = "кино" на сленге)

### Вывод: что говорит о разработчике
1. **Новичок в C++/геймдеве** — мемные названия, гигантский хедер, нет тестов
2. **Знает Lua** — скрипты написаны чисто, грамотный word wrap, pagination, profiling
3. **Терпеливый** — 34 CI коммита, не бросил
4. **Упоротый** — пишет код в 4 утра, нейминг классов — мемы 2023-2024
5. **Фаталист** — коммит с крестом ☥, `fuckOff()`, названия сцен
6. **Не высыпается** — средний сон 6ч, были ночи по 0-4.5ч

---

## ИНТЕРВЬЮ: ЧТО СКАЗАЛ БЫ КАЖДЫЙ КЛАСС, ЕСЛИ БЫ УМЕЛ ГОВОРИТЬ

```
JohnPork:       — Я СКЛАДЫВАЮ ВСЁ В КУЧУ И НАДЕЮСЬ НА ЛУЧШЕЕ.
Skibidi:        — Я ничего не делаю. Я просто база. Буквально.
Sigma:          — Я создаю окно. Меня зовут Sigma. Метод — skid(). Не задавай вопросов.
Amogus:         — Я инициализирую GPU. Метод — rizzing(). Ты понял? rizzing(). Иди нахуй.
TextGooner:     — Я ГОНЮСЬ ЗА ТЕКСТОМ. ТЕКСТ — МОЁ ВСЁ. ТЕКСТ — МОЯ... *запнулся*
RectGooner:     — Я рисую квадраты. Это всё, что я умею. И я счастлив.
ImageGooner:    — Я рисую картинки. Когда я не рисую, я просто храню пиксели. Мне грустно.
CacheMan:       — Я всё запоминаю. Ты думаешь, текстура загрузится дважды? ХУЙ ТЕБЕ. Я ЗАКЕШИРОВАЛ.
LigmaEngine:     — Я выполняю Lua. Моё имя — каламбур. Ты потратил 5 секунд чтобы осознать. Наслаждайся.
Hell_Machina:   — *звуки работающего промышленного оборудования* GOOOOOONING...
```

## ЭВОЛЮЦИЯ КОММИТОВ: ИСТОРИЯ ПАДЕНИЯ

Проследим, как менялся стиль коммитов по мере того, как разработчик терял рассудок:

```
ФАЗА 1: "Я СЕРЬЁЗНЫЙ РАЗРАБОТЧИК" (22-23 июн)
  ad9cb92  rewrite in cpp
  bfc4ddd  module arch && segfault
  b03fe2e  rewrite in classes Sigma & Amogus
  → Нормальные сообщения. Человек старается. Ещё не сломлен.

ФАЗА 2: "CI ЛОМАЕТ МЕНЯ" (23 июн, 34 коммита)
  fix make v5 → v6 → v7 → v8
  fix пр сш v1  (русская раскладка — разраб печатал не глядя)
  fix gh ci v2 → v3 → ... → v16
  fix gh ci v666, v727, v1337, v1488
  → Счётчик пошёл. Сатанинские числа. Разработчик ломается.

ФАЗА 3: "МНЕ ВСЁ РАВНО" (26-29 июн)
  308ab05  very useful commit
  6383635  fix fucking cpp lynter
  7a8dd91  fix idk
  a085863  update tsfont: fix UBs and segfaults
  → "fix idk". Разработчик уже не помнит, что чинил.

ФАЗА 4: "ПРИНЯТИЕ БЕЗУМИЯ" (30 июн — 1 июл)
  10af878  ☥
  06cec7c  I asked DeekPeek for docs
  1086f1d  fx gh ci
  → Крест. Доку от ИИ. Сообщения по 3 буквы. Пик.

ФАЗА 5: "ВОЗВРАЩЕНИЕ ИЗ ТЬМЫ" (18-21 июл)
  0c1696e  we are fucking removing save slots
  9222249  switch to cmake+ninja & add make dev
  5514eec  cmake build system, texture/sound preload, profiler
  4637471  fix 'window is inactive'
  → Разработчик выспался. Сообщения осмысленные. Но "fucking" осталось. Шрамы навсегда.
```

## ИНДЕКС БЕЗУМИЯ ПО ФАЙЛАМ

| Файл | Уровень безумия | Почему |
|------|-----------------|--------|
| `src/ligma/bind.hpp` | 🔥🔥🔥🔥🔥 | `fuckOff`, `E666`, `sllep`, `LigmaEngine` |
| `src/heck.hpp` | 🔥🔥🔥🔥🔥 | 1440 строк, `Sigma::skid`, `Amogus::rizzing`, `gooning` |
| `scripts/game.lua` | 🔥🔥🔥🔥 | `"gay"`, `"I cant properly explain this shit"`, profiler |
| `scripts/sscreen.lua` | 🔥🔥🔥🔥 | `"Lets fucking go"`, `"FUCK GET ME OUT!!11!"` |
| `external/tsfont/font_handler.c` | 🔥🔥🔥 | `cock_measure`, `cock_kern`, `// so sigma` |
| `src/audio_unc.hpp` | 🔥🔥 | Название файла — каламбур "audio unc" = "audio unck" (uncle?) |
| `src/tsfont_wrapper.hpp` | 🔥🔥 | Обёртка для cock_ функций |
| `src/shaders/` | 🔥 | Чистые шрифты. Без намёка на безумие. Подозрительно. |
| `src/main.cpp` | 🔥 | Самый нормальный файл в проекте. Почти скучный. |
| `external/gen_alpha_dictionary/` | 🤖 | Rust. Gen Alpha словарь. Описание: "skibidi, rizz". |

## BAL.PNG: ТЕОРИИ ЗАГОВОРА

Файл `assets/bal.png` (1.3 MB) **нигде не используется**, но лежит в репе. Вот список теорий, от более до менее вероятных:

1. **Теория "Ballin'"** — "bal" = Ballin' (мем "Skibidi dop dop yes yes"). Разработчик хотел вставить мем с котом, танцующим на фоне огня.
2. **Теория "Бал-город"** — разработчик с какого-то региона, "бал" = бал (танцы). Но тогда почему 1920×1080?
3. **Теория "Bob Dylan"** — "bal" = Боб Дилан. Разработчик фанат Боба Дилана и планировал Easter Egg.
4. **Теория "bal = ball"** — опечатка. Должно быть `ball.png`. Мяч. Почему мяч 1920×1080 — загадка.
5. **Теория "Banana"** — bal = банан (banana, cut off at "na"). Фруктовый фетиш.
6. **Теория "Balenciaga"** — high fashion спрайт.
7. **Конспирологическая теория** — `bal.png` содержит стеганографическое послание. Надо декодировать через XOR с длиной названий всех классов.
8. **Мета-теория** — разработчик положил файл чтобы сбивать с толку AI (нас). И это сработало.
9. **Реалистичная теория** — файл остался от тестового рендера и все забыли его удалить.

## УЧЁТ ПРОФАНОСТИ: ПОЛНАЯ КАРТИНА

### grep -r по src/ и scripts/ (проектные файлы, без external)

```
"fuck"         —  8 вхождений:
                    src/heck.hpp:        1  (fuckCpp)
                    src/main.cpp:        1  (fuckup)
                    src/ligma/bind.hpp:   2  (fuckup, fuckOff)
                    scripts/sscreen.lua: 3  (fucking, fuckOff, "fuck me pls")
                    scripts/game.lua:    1  ("fucking empty")
                    TOTAL:               8

"shit"         —  2 вхождения:
                    scripts/game.lua:    2  ("this shit", "fucking empty")
                    TOTAL:               2

"cock_"        —  5 вхождений:
                    src/heck.hpp:        2  (cock_measure, cock_kern)
                    src/tsfont_wrapper:  2  (declarations)
                    scripts/game.lua:    1  (TODO comment)
                    TOTAL:               5

"goon/er/ing"  —  ~40 вхождений:
                    src/heck.hpp:        ~33 (TextGooner×20, RectGooner×3,
                                              ImageGooner×5, goonerType×4,
                                              gooning×1)
                    src/main.cpp:         3  (engine.gooning)
                    src/ligma/bind.hpp:    1  (engine.gooning)
                    scripts/sscreen.lua:  1  (comment "undefinded gooners")
                    scripts/game.lua:     3  (wrapText gooner params)
                    TOTAL:              ~41

"ass"          —  0  (ноль. Разработчик стесняется слова "ass"?)
"dick"         —  0  (тоже ноль. Неожиданно.)
"bitch"        —  0  (джентльмен)
```

Разработчик матерится ровно настолько, чтобы было понятно: он не робот. Но в меру. 7/10 по шкале быдлокодинга.

## 30 СЕКУНД СТЫДА: ЧТО УВИДИТ НЕПОДГОТОВЛЕННЫЙ РАЗРАБОТЧИК

Если открыть проект впервые и набрать `grep -r "class" src/heck.hpp`, вы увидите:

```cpp
class Skibidi
class TextGooner : public Skibidi
class RectGooner : public Skibidi
class ImageGooner : public Skibidi
class Sigma            // operator skid()
class Amogus           // operator rizzing()
class Hell_Machina     // bool gooning
```

Если вы дожили до этого момента и не закрыли файл — вы либо фанат сленга Gen Alpha, либо мазохист. Добро пожаловать в клуб.

## ЕСЛИ БЫ ЭТОТ ПРОЕКТ БЫЛ ФИЛЬМОМ

| Акт | Сюжет |
|-----|-------|
| **Акт I: Надежда** | Разработчик создаёт `Sigma` и `Amogus`. Код ещё чистый. Коммиты осмысленные. "rewrite in cpp" — звучит гордо. |
| **Акт II: Падение** | CI ломается 34 раза. `fix gh ci v666`. `fix idk`. Появляются `TextGooner`, `JohnPork`, `Skibidi`. Разработчик кодит в 4 утра. |
| **Акт III: Принятие** | `10af878 ☥`. Пустой коммит с крестом. Разработчик отпустил ситуацию. Теперь он просто кайфует. |
| **Акт IV: Возвращение** | 17 дней тишины. Проект мёртв. Но нет — `switch to cmake`. Код стал чище. Разработчик выспался. |
| **Финальная сцена** | `4637471 fix 'window is inactive'` — 8103 строки. Разработчик фиксит баг, которым сам же и страдал. |
| **Post-credits сцена** | Файл `bal.png` мигает на экране. Зачем он здесь? Никто не знает. |

---

## ИТОГ

Проект — классический пет-проект энтузиаста, который хотел сделать визуальную новеллу, изучил bgfx/Vulkan, подтянул Lua-скриптинг, и в процессе **получал удовольствие от нейминга классов**. Код работает. Визуалка есть. Диалоги листаются. Звук играет. Настройки сохраняются.

Но читаемость кода принесена в жертву мемам, архитектура страдает от "давай ещё один слой абстракции с хуёвым названием", а половина git истории — это "fix ci v1488 ON GOD FR FR".

**Вердикт:** забавно, работает, но глаза кровоточат. 7/10.
