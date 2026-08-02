cmake_minimum_required(VERSION 3.20)
project(insane_night LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Release")
  add_compile_options(-O3 -DNDEBUG)
  add_compile_definitions(BX_CONFIG_DEBUG=0)
  add_link_options(-flto=auto -s)
  message(STATUS "[insane_night] Release: -O3 -flto -s")
else()
  add_compile_options(-O0 -g)
  add_compile_definitions(BX_CONFIG_DEBUG=1)
  message(STATUS "[insane_night] Debug: -O0 -g")
endif()

find_package(PkgConfig REQUIRED)
find_package(Freetype REQUIRED)
pkg_check_modules(SDL3 REQUIRED sdl3)

set(PROJECT_INCLUDE_DIRS
  src
  src/ligma
  external
  external/tsfont
  external/bgfx/include
  external/bx/include
  external/bimg/include
  external/SDL/include
  external/lua-5.4.8/src
  external/sol2/include
  external/soloud20200207/include
)

add_library(tsfont_obj OBJECT external/tsfont/font_handler.c)
target_include_directories(tsfont_obj PRIVATE
  external/tsfont
  ${FREETYPE_INCLUDE_DIRS}
)

file(GLOB LUA_C_SRCS external/lua-5.4.8/src/*.c)
list(REMOVE_ITEM LUA_C_SRCS
  ${CMAKE_SOURCE_DIR}/external/lua-5.4.8/src/lua.c
  ${CMAKE_SOURCE_DIR}/external/lua-5.4.8/src/luac.c
)
add_library(lua STATIC ${LUA_C_SRCS})
target_include_directories(lua PUBLIC external/lua-5.4.8/src)
target_compile_definitions(lua PRIVATE LUA_COMPAT_5_3 LUA_USE_LINUX)
target_link_libraries(lua PUBLIC m)

file(GLOB SOLOUD_CORE external/soloud20200207/src/core/*.cpp)
file(GLOB SOLOUD_WAV external/soloud20200207/src/audiosource/wav/*.cpp)
file(GLOB SOLOUD_FILTERS external/soloud20200207/src/filter/*.cpp)
set(SOLOUD_SRCS
  ${SOLOUD_CORE}
  ${SOLOUD_WAV}
  ${SOLOUD_FILTERS}
  ${CMAKE_SOURCE_DIR}/external/soloud20200207/src/audiosource/wav/stb_vorbis.c
  ${CMAKE_SOURCE_DIR}/external/soloud20200207/src/backend/miniaudio/soloud_miniaudio.cpp
)
add_library(soloud STATIC ${SOLOUD_SRCS})
target_include_directories(soloud PUBLIC
  external/soloud20200207/include
  external/soloud20200207/src/backend/miniaudio
)
target_compile_definitions(soloud PRIVATE WITH_MINIAUDIO)
target_link_libraries(soloud PUBLIC m)

pkg_check_modules(ALSA alsa QUIET)
if(ALSA_FOUND)
  target_include_directories(soloud PRIVATE ${ALSA_INCLUDE_DIRS})
  target_link_libraries(soloud PUBLIC ${ALSA_LIBRARIES})
endif()

foreach(LIB bgfx bimg bx)
  add_library(${LIB}_ext STATIC IMPORTED)
  set_target_properties(${LIB}_ext PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/external/lib/lib${LIB}.a
  )
endforeach()

add_executable(insane_night
  src/main.cpp
  src/heck.cpp
  src/audio_unc.cpp
  src/ligma/ligma.cpp
  $<TARGET_OBJECTS:tsfont_obj>
)
target_include_directories(insane_night PRIVATE
  ${PROJECT_INCLUDE_DIRS}
  ${FREETYPE_INCLUDE_DIRS}
  ${SDL3_INCLUDE_DIRS}
)
target_link_libraries(insane_night
  lua
  soloud
  bgfx_ext
  bimg_ext
  bx_ext
  Freetype::Freetype
  ${SDL3_LIBRARIES}
  pthread dl m
)

# ── Tests (pure-logic, no window/bgfx init) ───────────────────
add_executable(insane_night_tests
  "tests(vibecoded)/cpp/test_logic.cpp"
)
target_include_directories(insane_night_tests PRIVATE
  ${PROJECT_INCLUDE_DIRS}
  ${FREETYPE_INCLUDE_DIRS}
  ${SDL3_INCLUDE_DIRS}
)
target_link_libraries(insane_night_tests
  Freetype::Freetype
  ${SDL3_LIBRARIES}
  pthread dl m
)
enable_testing()
add_test(NAME insane_night_tests COMMAND insane_night_tests)
