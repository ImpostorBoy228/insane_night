# RAM Analysis — Insane Night

> Полный аудит памяти проекта. Дата: 29 Jul 2026.
> Измерено: `heaptrack` на debug-сборке, запуск 9 секунд.

---

## Фактические замеры (heaptrack)

| Метрика | Значение |
|---------|----------|
| **Peak heap consumption** | **261.29 MB** |
| **Peak RSS (включая heaptrack overhead)** | **473.03 MB** |
| Всего allocation calls | 177,551 |
| Temporary allocations | 18,979 |
| Время работы | 9.1 сек |

### Топ-10 потребителей heap

| # | Размер | Откуда | Описание |
|---|--------|--------|----------|
| 1 | **126.65 MB** | `bgfx::AllocatorStub::realloc` (bgfx.cpp:348) | GPU render buffers, texture uploads — 144 вызовов |
| 2 | **113.74 MB** | `SoLoud::Wav::loadmp3` (soloud_wav.cpp:198) | **2 MP3 декодированы в float PCM** — 57 MB каждый! |
| 3 | **62.79 MB** | `Amogus::rizzing` (heck.hpp:1378) | bgfx context init, 1 вызов |
| 4 | **27.50 MB** | `bgfx::copy` через `CacheMan::preloadTextures` (heck.hpp:199) | 6 текстур → RGBA8 upload |
| 5 | **8.39 MB** ×2 | `bgfx::Context::init` | Внутренние буферы bgfx |
| 6 | **6.29 MB** | `bgfx::Context::init` | Ещё внутренние буферы |
| 7 | **7.12 MB** | `libgallium` | GPU драйвер NVIDIA |
| 8 | **2.31 MB** | `std::allocator::allocate` (7909 вызовов) | C++ аллокации гейм-кода |
| 9 | **786 KB** | `SoLoud::AlignedFloatBuffer::init` | Audio mixing buffers |
| 10 | **655 KB** | `libnvidia-eglcore` | NVIDIA EGL driver |

### Анализ текстур (6 шт)

| Файл | Размер | RGBA8 в RAM |
|------|--------|-------------|
| `background.png` | 279 KB | **7.91 MB** (1920×1080) |
| `bal.png` | 1,315 KB | **4.99 MB** (1616×810) |
| `cirno.png` | 180 KB | **1.37 MB** (600×600) |
| `osuback.png` | 2,154 KB | **7.91 MB** (1920×1080) |
| `sans.jpg` | 33 KB | **3.52 MB** (1280×720) |
| `sans.png` | 32 KB | **0.52 MB** (321×424) |
| **Total** | **~4 MB compressed** | **~26 MB GPU upload** |

### Анализ звуков (2 MP3)

| Файл | Сжатый | PCM float (44100Hz, stereo) |
|------|--------|------------------------------|
| `megalovania.mp3` | 2.5 MB | **~57 MB** |
| `pablo_.mp3` | 2.2 MB | **~57 MB** |
| **Total** | **4.7 MB** | **114 MB в RAM** |

---

## Текущее распределение RAM (~261 MB peak)

``` 
MP3 PCM декодирование (SoLoud):      113.7 MB  ← 🔴 44%
GPU render buffers (bgfx):           126.7 MB  ← 🟡 48%
  ├── allocator stub:                 126.7 MB
Текстуры RGBA8 (bgfx copy):           27.5 MB  ← 🟢 11%
bgfx context init:                     23.1 MB
Прочие C++ аллокации:                   2.3 MB  ← 🟢 1%
SoLoud audio mixing:                    0.8 MB
```

---

## Ключевые открытия

### 🔴 1. MP3 декодирование — 113.7 MB просто в RAM
Два MP3 файла декодируются в `float*` PCM (4 байта/sample). Оба файла — длинные треки (~5 мин при 44100 Hz stereo = 300×44100×2×4 = 105 MB/трек). **Висят в RAM навсегда** (кэш в AudioEngine::sounds без эвикции).

**Решение**: 
- Использовать стриминг для длинных треков (bgfx/SoLoud does not support streaming — need custom)
- Конвертировать в mono если не нужно стерео
- Обрезать длительность треков
- OGG Vorbis с более агрессивным сжатием не поможет — PCM будет таким же
- Wav-формат тоже будет float PCM — размер не изменится

---

---

## Измеренный Peak: **261 MB heap** / **473 MB RSS**

> **44% RAM** — два MP3 трека декодированы в PCM float (114 MB)
> **48% RAM** — bgfx GPU render buffers (127 MB)
> **11% RAM** — текстуры RGBA8 (27 MB)

---

## Сводка: 🔴 Критические проблемы

| # | Проблема | Файл | RAM-влияние |
|---|----------|------|-------------|
| 1 | **Нет эвикции кэшей** | cacheMan, TextGooner, AudioEngine, textGooners | ∞ — все кэши только растут |
| 2 | **Слои нельзя удалить** | heck.hpp:1437-1438 | ∞ — sceneLayers/uiLayers deque растут вечно |
| 3 | **preloadTextures жрёт всю RAM** | heck.hpp:167-210 | Пик: все текстуры декодированы в RAM одновременно |
| 4 | **Atlas CPU-side копия всегда в RAM** | TextGooner::atlasPixels (heck.hpp:864) | 4 MB постоянно, даже после GPU upload |
| 5 | **Sound cache держит весь PCM** | audio_unc.hpp:33 | 1 MB/сек стерео 44.1kHz — каждый звук навсегда |
| 6 | **Dangling captures в лямбдах** | bind.hpp:9 (ligma_bind) | UB — ссылки на локальные переменные после выхода из функции |

---

## 1. CacheMan — Кэш текстур (`heck.hpp:104-211`)

### Структуры

| Поле | Тип | Рост | Очистка |
|------|-----|------|---------|
| `texturePaths` | `vector<string>` | emplace_back на каждый loadTexture | .clear() только в destroy() |
| `textures` | `unordered_map<string, CachedTexture>` | emplace на каждый новый texture | .clear() только в destroy() |

**CachedTexture** = 2×int + bgfx::TextureHandle = ~12 байт + map overhead ~32-40 байт.
**GPU memory**: каждая текстура RGBA8 = w × h × 4 байт на GPU. Никогда не освобождается.

### preloadTextures — Пиковый RAM-взрыв

- `files: vector<string>` — все имена файлов в директории
- `futures: vector<future<Decoded>>` — каждый `Decoded` содержит `vector<uint8_t> pixels` = w × h × 4
- **ВСЕ декодированные изображения существуют в RAM одновременно** до первого GPU upload
- Пример: 50 текстур 1920x1080 = 50 × 8 MB = **400 MB пик**
- После upload каждый Decoded разрушается

**Оптимизация**: грузить и аплоадить по одной текстуре, а не все сразу.

---

## 2. JohnPork — Батч-рендерер (`heck.hpp:238-305`)

| Поле | Тип | Персистентность |
|------|-----|-----------------|
| `batches` | `vector<Batch>` | clear() каждый фрейм, но **capacity не уменьшается** |
| `Batch::vertices` | `vector<uint8_t>` | high-water mark навсегда |
| `Batch::indices` | `vector<uint16_t>` | high-water mark навсегда |

**BatchKey** = 52 байта. Каждый Batch ~104 байта + heap vertices/indices.

**getOrCreate** — линейный поиск O(n) через весь вектор.

**Оптимизации**:
- `shrink_to_fit()` раз в 60 фреймов
- Заменить линейный поиск на хеш-таблицу по BatchKey

---

## 3. TextGooner — Шрифты и атлас (`heck.hpp:541-870`)

### Atlas Pixel Buffer (CPU)
```cpp
std::vector<uint8_t> atlasPixels;  // line 864
```

| Стадия | Размер | CPU RAM | GPU RAM (R8) |
|--------|--------|---------|--------------|
| Начальный | 512×512 | 256 KB | 256 KB |
| После 1-го роста | 1024×1024 | 1 MB | 1 MB |
| Максимум | 2048×2048 | **4 MB** | 4 MB |

**CPU-side копия** никогда не освобождается. Даже после GPU upload висит 4 MB.

### Glyph Map — НЕОГРАНИЧЕННЫЙ РОСТ
```cpp
std::unordered_map<uint32_t, GlyphData> glyphs;  // line 862
```

- Key: uint32_t (4 байта)
- Value: GlyphData ~48 байт + map node ~32 байта = **~80 байт на глиф**
- 5000 глифов = 400 KB, 50000 глифов = 4 MB
- **Никогда не очищается**

### packedGlyphs — Тоже бесконечный рост
```cpp
std::vector<uint32_t> packedGlyphs;  // line 863
```
4 байта на глиф. Тоже никогда не очищается. И вообще не используется нигде — dead data.

### Font File в RAM
```cpp
std::vector<unsigned char> fontBytes;  // line 401
```
Весь .ttf файл в памяти (100 KB - 5 MB) + распаршенный font (ещё столько же).

---

## 4. Skibidi — UI Элементы

### Text (heck.hpp:872-1052)
- `cachedVertices: vector<Vertex>` — 20 байт/вершина, 4 вершины на глиф = 80 байт/символ
- `cachedIndices: vector<uint16_t>` — 12 байт/символ
- 100 символов = ~9 KB кэша + string text

### Rectangle (heck.hpp:1054-1093)
- 4 float + uint32_t = 20 байт, стек-аллоцированные вершины
- **Нет heap-аллокаций** ✓

### Image (heck.hpp:1095-1135)
- 4 float + uint32_t + TextureHandle = 24 байта, стек-аллокации
- **Нет heap-аллокаций** ✓

### Skibidi Base (heck.hpp:460-490)
- ~120 байт на объект + heap для type string + onClick std::function

---

## 5. Layer System (`heck.hpp:1156-1262`)

| Поле | Тип | Рост |
|------|-----|------|
| `name` | string | Один раз |
| `items` | `vector<unique_ptr<Skibidi>>` | add<T>() |
| `clickables` | `vector<Clickable>` | addClickable() |

**Clickable** = 4×float + std::function + 4×float (frac) = ~65 байт.

### **Проблема**: слои нельзя удалить
```cpp
std::deque<Layer> sceneLayers;   // heck.hpp:1437
std::deque<Layer> uiLayers;      // heck.hpp:1438
```
Есть `addSceneLayer` / `addUILayer`, но **нет remove**. При каждом scene switch создаётся новый слой, старый остаётся в deque и висит в RAM.

Lua scene switching pattern (`main.lua:54-75`):
```lua
local layerName = "scene_" .. name
local ui = getUILayer(layerName)
if not ui then ui = addUILayer(layerName) end  -- новый слой, старый не удаляется
```
Слой для "menu", "gay", "settings" создаются один раз и остаются. Но если делать switchTo на динамические имена — слои будут копиться.

---

## 6. AudioEngine — Звуки (`audio_unc.hpp/cpp`)

### Неограниченный кэш звуков
```cpp
std::unordered_map<std::string, std::unique_ptr<SoLoud::Wav>> sounds;  // audio_unc.hpp:33
```
- Ключ: string (путь к файлу)
- Значение: SoLoud::Wav с полным PCM в `float* mData`
- **Никогда не очищается** (кроме deinit)

### Формула RAM на звук
```
samples × channels × sizeof(float) = длительность_сек × частота × каналы × 4
```
- 3 сек 44.1kHz стерео = **~1 MB**
- 60 сек 44.1kHz стерео = **~20 MB**
- 0.5 сек 22kHz моно = **~43 KB**

### SoLoud Internal Buffers
- `mVoice[1024]` = 8 KB (фикс)
- `m3dData[1024]` = ~200 KB (фикс)
- `mResampleData` = до ~32 MB (capped, но потенциально много)

### Оптимизации
- C++20 heterogeneous lookup для map (избежать std::string аллокации на каждый playSound)
- LRU eviction или max-size для кэша
- `unloadSound(path)` API

---

## 7. tsfont — Рендеринг глифов (`external/tsfont/font_handler.c`)

### font_load (line 51-91)
- Создаёт FT_Library + FT_Face через FreeType
- Аллоцирует `struct FontHandle { FT_Face; FT_Library; }` = 16 байт
- FreeType internally аллоцирует таблицы шрифта при FT_New_Memory_Face

### font_free (line 93-100)
- Корректно чистит: FT_Done_Face → FT_Done_FreeType → free(handle)

### font_fill_glyphs (line 135-241)
- **Двойной рендер**: сначала scan чтобы посчитать total_bytes, потом второй раз рендерит те же глифы
- Аллоцирует `bitmap_buf = malloc(total_bytes)` — все битмапы глифов в одном буфере
- Возвращает `GlyphInfo*` массив (48 байт на глиф)
- Вызывающий (TextGooner::appendGlyphs) должен вызвать `free_bitmap_buffer`

### **Потенциальная проблема**: двойной FT_Load_Glyph для каждого глифа
Не RAM, но CPU. FreeType делает hinting + rasterization дважды.

---

## 8. Lua Bindings — sol2 (`ligma/bind.hpp`)

### 🔴 Dangling References

Вся функция `ligma_bind` (bind.hpp) использует `[&]` capture:
```cpp
auto bind_click_callback = [report_lua_error](const sol::protected_function& cb) { ... };
```
Локальные переменные (`bind_click_callback`, `report_lua_error`) захвачены по ссылке в лямбдах, которые хранятся в Lua registry. После выхода из `ligma_bind` эти ссылки висячие.

### Usertype Registration
19 C++ функций зарегистрированы в Lua global table навсегда.
Ни один usertype не имеет GC finalizer — Lua не чистит C++ объекты.

### `sol::protected_function` предотвращает GC
Каждый onClick хранит `sol::protected_function`, который держит registry reference на Lua функцию. Пока жив C++ объект — Lua функция не будет GC-собрана.

---

## 9. Lua Скрипты

### main.lua
- `scenes = {}` — таблица растёт с каждым `register()`, но это ожидаемо (один раз за сцену)
- `Settings = {}` — глобальная, висит навсегда (3 поля)
- `currentScene` хранит reference на Layer — преграждает GC слоя? Нет, Layer в C++.

### game.lua
- `vn.currentChoices` — **растёт с каждым выбором игрока**: `table.insert(vn.currentChoices, {node=..., choice=...})` (line 504). Не чистится между сценами — только при загрузке/ините
- `scriptData` — весь JSON диалогов (~300 строк) в RAM навсегда
- `prof.buf` — если prof.enabled=true, таблица растёт пока prof.flush() не вызван

### sscreen.lua / settings.lua
- Минимальное потребление: несколько Rect + Text элементов
- `g` local таблицы хранят references на TextGooner/RectGooner

---

## 10. Итог: Потенциальные утечки

### 🔴 Unbounded growth (никогда не очищается)
1. `CacheMan::textures` — каждая загруженная текстура навсегда
2. `CacheMan::texturePaths` — то же
3. `TextGooner::glyphs` — каждый уникальный codepoint навсегда
4. `TextGooner::packedGlyphs` — то же + dead data
5. `AudioEngine::sounds` — каждый загруженный звук навсегда
6. `Hell_Machina::textGooners` — каждый уникальный font+size навсегда
7. `Hell_Machina::sceneLayers/uiLayers` — слои добавляются но не удаляются

### 🔴 High peak memory
8. `preloadTextures` — все текстуры декодируются в RAM параллельно
9. `TextGooner::atlasPixels` — CPU-side копия атласа 4 MB вечно

### 🟡 Excessive allocations
10. JohnPork: capacity никогда не shrink'ится
11. `audio_unc.cpp:65` — std::string конверсия на каждый playSound
12. tsfont: двойной рендер глифов в font_fill_glyphs

### 🟡 Lua-side
13. `vn.currentChoices` растёт с каждым выбором
14. Lua onClick callback'и живут пока жив C++ объект

---

## 11. Рекомендации

| Приоритет | Что делать | Где |
|-----------|-----------|-----|
| 🔴 P0 | Добавить `removeSceneLayer` / `removeUILayer` | heck.hpp:1437-1438 |
| 🔴 P0 | LRU eviction для CacheMan (max 100 текстур) | heck.hpp:106 |
| 🔴 P0 | LRU eviction для AudioEngine::sounds | audio_unc.hpp:33 |
| 🔴 P1 | Стримить preloadTextures по одной, а не все сразу | heck.hpp:167-210 |
| 🔴 P1 | Ограничить glyph map (max 2000) | heck.hpp:862 |
| 🟡 P2 | Убрать CPU atlasPixels после GPU upload | heck.hpp:864 |
| 🟡 P2 | `batches.shrink_to_fit()` раз в 60 фреймов | heck.hpp:245 |
| 🟡 P2 | Убрать `packedGlyphs` — dead code | heck.hpp:863 |
| 🟡 P2 | C++20 heterogeneous lookup для sound map | audio_unc.cpp:65 |
| 🟡 P2 | Исправить `[&]` capture в ligma_bind | bind.hpp:9 |
| 🟢 P3 | Ограничить `vn.currentChoices` (или чистить при scene switch) | game.lua:504 |
| 🟢 P3 | `fontBytes` можно освобождать после font_load | heck.hpp:401 |