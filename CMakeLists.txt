cmake_minimum_required(VERSION 3.20)
project(insane_night LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_FLAGS_RELEASE "-O2 -DNDEBUG")
set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-s")

add_compile_definitions(BX_CONFIG_DEBUG=0)

include_directories(
    external
    external/bgfx/include
    external/bx/include
    external/bimg/include
    external/SDL/include
    external/tsfont
    /usr/include/freetype2
    external/sol2/include
    external/lua-5.4.8/src
    external/json/single_include
    external/soloud20200207/include
    external/soloud20200207/src
)

file(GLOB LUA_SRCS external/lua-5.4.8/src/*.c)
list(REMOVE_ITEM LUA_SRCS
    ${CMAKE_SOURCE_DIR}/external/lua-5.4.8/src/lua.c
    ${CMAKE_SOURCE_DIR}/external/lua-5.4.8/src/luac.c
)
add_library(lua STATIC ${LUA_SRCS})
set_property(TARGET lua PROPERTY C_STANDARD 99)
target_compile_definitions(lua PRIVATE LUA_COMPAT_5_3 LUA_USE_LINUX)

file(GLOB SOLOUD_CORE_SRCS external/soloud20200207/src/core/*.cpp)
set(SOLOUD_SRCS
    ${SOLOUD_CORE_SRCS}
    external/soloud20200207/src/backend/miniaudio/soloud_miniaudio.cpp
    external/soloud20200207/src/audiosource/wav/dr_impl.cpp
    external/soloud20200207/src/audiosource/wav/soloud_wav.cpp
    external/soloud20200207/src/audiosource/wav/stb_vorbis.c
)
add_library(soloud OBJECT ${SOLOUD_SRCS})
target_compile_definitions(soloud PRIVATE WITH_MINIAUDIO)

set(SOURCES
    src/main.cpp
    src/heck.cpp
    external/tsfont/font_handler.c
    src/ligma/ligma.cpp
    src/audio_unc.cpp
)

add_executable(insane_night ${SOURCES} $<TARGET_OBJECTS:soloud>)
set_target_properties(insane_night PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR})
target_link_libraries(insane_night PRIVATE lua)

target_link_libraries(insane_night PRIVATE
    -Wl,--whole-archive
    ${CMAKE_SOURCE_DIR}/external/lib/libbgfx.a
    ${CMAKE_SOURCE_DIR}/external/lib/libbx.a
    ${CMAKE_SOURCE_DIR}/external/lib/libbimg.a
    -Wl,--no-whole-archive
    SDL3 X11 dl pthread freetype vulkan
)
