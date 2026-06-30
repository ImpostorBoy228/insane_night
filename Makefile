CC   = gcc
CXX  = g++
MAKEFLAGS += -j16
COMPDB = compile_commands.json
CXXFLAGS_BASE = -std=c++23 -O2 -DBX_CONFIG_DEBUG=0
CXXFLAGS = $(CXXFLAGS_BASE) -Wall -Wextra
SOLOUD_CXXFLAGS = $(CXXFLAGS_BASE)
CFLAGS   = -std=c11 -Wall -Wextra -O2 -DBX_CONFIG_DEBUG=0
INCLUDES = -Iexternal -Iexternal/bgfx/include -Iexternal/bx/include -Iexternal/bimg/include -Iexternal/SDL/include -Iexternal/tsfont -I/usr/include/freetype2 -Iexternal/sol2/include -Iexternal/lua-5.4.8/src -Iexternal/json/single_include -Iexternal/soloud20200207/include -Iexternal/soloud20200207/src
LDFLAGS  = -lSDL3 -lX11 -lGL -ldl -lpthread -lfreetype
LIBS     = external/lib/libbgfx.a external/lib/libbx.a external/lib/libbimg.a

SOLOUD_DEFINES = -DWITH_MINIAUDIO
SOLOUD_SRCS = $(wildcard external/soloud20200207/src/core/*.cpp) external/soloud20200207/src/backend/miniaudio/soloud_miniaudio.cpp
SOLOUD_OBJS = $(SOLOUD_SRCS:.cpp=.o)

OBJS = main.o heck.o font_handler.o script_engine.o audio_unc.o

all: compdb insane_night

insane_night: $(OBJS) $(SOLOUD_OBJS) external/lua-5.4.8/src/liblua.a
	$(CXX) $(OBJS) $(SOLOUD_OBJS) $(LIBS) external/lua-5.4.8/src/liblua.a $(LDFLAGS) -o insane_night

external/lua-5.4.8/src/liblua.a:
	$(MAKE) -C external/lua-5.4.8/src linux

main.o: src/main.cpp
	$(CXX) -c src/main.cpp $(CXXFLAGS) $(INCLUDES) -o main.o

heck.o: src/heck.cpp
	$(CXX) -c src/heck.cpp $(CXXFLAGS) $(INCLUDES) -o heck.o

audio_unc.o: src/audio_unc.cpp src/audio_unc.hpp
	$(CXX) -c src/audio_unc.cpp $(CXXFLAGS) $(INCLUDES) -o audio_unc.o

font_handler.o: external/tsfont/font_handler.c
	$(CC) -c external/tsfont/font_handler.c $(CFLAGS) $(INCLUDES) -o font_handler.o

script_engine.o: src/ligma/ligma.cpp src/ligma/ligma.hpp
	$(CXX) -c src/ligma/ligma.cpp $(CXXFLAGS) $(INCLUDES) -o script_engine.o

external/soloud20200207/src/%.o: external/soloud20200207/src/%.cpp
	$(CXX) -c $< $(SOLOUD_CXXFLAGS) $(INCLUDES) $(SOLOUD_DEFINES) -o $@

$(COMPDB):
	@printf '[\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/heck.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "$(CURDIR)/src/heck.cpp"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/main.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "$(CURDIR)/src/main.cpp"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CC) -c external/tsfont/font_handler.c $(CFLAGS) $(INCLUDES)",\n    "file": "$(CURDIR)/external/tsfont/font_handler.c"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/ligma/ligma.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "$(CURDIR)/src/ligma/ligma.cpp"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/audio_unc.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "$(CURDIR)/src/audio_unc.cpp"\n  }\n]\n' > $@

compdb: $(COMPDB)

clean:
	rm -f *.o $(SOLOUD_OBJS) insane_night $(COMPDB)
	rm -rf gcm.cache
	rm -f main.s
	rm -f scripts/embed
	$(MAKE) -C external/lua-5.4.8/src clean

.PHONY: all clean compdb
