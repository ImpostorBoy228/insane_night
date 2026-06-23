CXX = g++
CXXFLAGS = -std=c++23 -Wall -Wextra -O2 -fmodules-ts
INCLUDES = -Iexternal/bgfx/include -Iexternal/bx/include -Iexternal/bimg/include
LDFLAGS  = -lSDL3 -lX11 -lGL -ldl -lpthread
LIBS     = external/lib/libbgfx.a external/lib/libbx.a external/lib/libbimg.a

all: insane_night

insane_night: main.o heck.o
	$(CXX) main.o heck.o $(LIBS) $(LDFLAGS) -o insane_night

main.o: src/main.cpp heck.o
	$(CXX) -c src/main.cpp $(CXXFLAGS) $(INCLUDES) -o main.o

heck.o: src/heck.cpp
	$(CXX) -c src/heck.cpp $(CXXFLAGS) $(INCLUDES) -o heck.o

clean:
	rm -f *.o insane_night
	rm -rf gcm.cache
	rm -f main.s
