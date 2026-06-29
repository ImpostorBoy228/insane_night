CC   = gcc
CXX  = g++
MAKEFLAGS += -j16
COMPDB = compile_commands.json
CXXFLAGS = -std=c++23 -Wall -Wextra -O2 -DBX_CONFIG_DEBUG=0
CFLAGS   = -std=c11 -Wall -Wextra -O2 -DBX_CONFIG_DEBUG=0
INCLUDES = -Iexternal -Iexternal/bgfx/include -Iexternal/bx/include -Iexternal/bimg/include -Iexternal/SDL/include -Iexternal/tsfont -I/usr/include/freetype2 -Iexternal/sol2/include -Iexternal/lua-5.4.8/src -Iexternal/json/single_include
LDFLAGS  = -lSDL3 -lX11 -lGL -ldl -lpthread -lfreetype
LIBS     = external/lib/libbgfx.a external/lib/libbx.a external/lib/libbimg.a

all: compdb insane_night

insane_night: main.o heck.o font_handler.o script_engine.o external/lua-5.4.8/src/liblua.a
	$(CXX) main.o heck.o font_handler.o script_engine.o $(LIBS) external/lua-5.4.8/src/liblua.a $(LDFLAGS) -o insane_night

external/lua-5.4.8/src/liblua.a:
	$(MAKE) -C external/lua-5.4.8/src linux

main.o: src/main.cpp
	$(CXX) -c src/main.cpp $(CXXFLAGS) $(INCLUDES) -o main.o

heck.o: src/heck.cpp
	$(CXX) -c src/heck.cpp $(CXXFLAGS) $(INCLUDES) -o heck.o

font_handler.o: external/tsfont/font_handler.c
	$(CC) -c external/tsfont/font_handler.c $(CFLAGS) $(INCLUDES) -o font_handler.o

script_engine.o: src/ligma/ligma.cpp src/ligma/ligma.hpp
	$(CXX) -c src/ligma/ligma.cpp $(CXXFLAGS) $(INCLUDES) -o script_engine.o

$(COMPDB):
	@printf '[\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/heck.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "src/heck.cpp"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/main.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "src/main.cpp"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CC) -c external/tsfont/font_handler.c $(CFLAGS) $(INCLUDES)",\n    "file": "external/tsfont/font_handler.c"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/ligma/ligma.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "src/ligma/ligma.cpp"\n  }\n]\n' > $@

compdb: $(COMPDB)

clean:
	rm -f *.o insane_night $(COMPDB)
	rm -rf gcm.cache
	rm -f main.s
	rm -f scripts/embed
	$(MAKE) -C external/lua-5.4.8/src clean

.PHONY: all clean compdb
