CC   = gcc
CXX  = g++
MAKEFLAGS += -j16
COMPDB = compile_commands.json
CXXFLAGS = -std=c++23 -Wall -Wextra -O2 -DBX_CONFIG_DEBUG=0
CFLAGS   = -std=c11 -Wall -Wextra -O2 -DBX_CONFIG_DEBUG=0
INCLUDES = -Iexternal -Iexternal/bgfx/include -Iexternal/bx/include -Iexternal/bimg/include -Iexternal/SDL/include -Iexternal/tsfont -I/usr/include/freetype2
LDFLAGS  = -lSDL3 -lX11 -lGL -ldl -lpthread -lfreetype
LIBS     = external/lib/libbgfx.a external/lib/libbx.a external/lib/libbimg.a

all: compdb insane_night

insane_night: main.o heck.o font_handler.o
	$(CXX) main.o heck.o font_handler.o $(LIBS) $(LDFLAGS) -o insane_night

main.o: src/main.cpp
	$(CXX) -c src/main.cpp $(CXXFLAGS) $(INCLUDES) -o main.o

heck.o: src/heck.cpp
	$(CXX) -c src/heck.cpp $(CXXFLAGS) $(INCLUDES) -o heck.o

font_handler.o: external/tsfont/font_handler.c
	$(CC) -c external/tsfont/font_handler.c $(CFLAGS) $(INCLUDES) -o font_handler.o

$(COMPDB):
	@printf '[\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/heck.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "src/heck.cpp"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CXX) -c src/main.cpp $(CXXFLAGS) $(INCLUDES)",\n    "file": "src/main.cpp"\n  },\n  {\n    "directory": "$(CURDIR)",\n    "command": "$(CC) -c external/tsfont/font_handler.c $(CFLAGS) $(INCLUDES)",\n    "file": "external/tsfont/font_handler.c"\n  }\n]\n' > $@

compdb: $(COMPDB)

clean:
	rm -f *.o insane_night $(COMPDB)
	rm -rf gcm.cache
	rm -f main.s

.PHONY: all clean compdb
