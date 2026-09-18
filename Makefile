CC      = clang
CXX     = clang++
CFLAGS  = -std=c17 -O3 -DNDEBUG -DBX_CONFIG_DEBUG=0
CXXFLAGS= -std=gnu++26 -O3 -DNDEBUG -DBX_CONFIG_DEBUG=0

SRC_DIR = src
EXT_DIR = external
TESTS_DIR = "tests(vibecoded)/cpp"

INC = -I$(SRC_DIR) \
      -I$(SRC_DIR)/ligma \
      -I$(EXT_DIR) \
      -I$(EXT_DIR)/tsfont \
      -I$(EXT_DIR)/bgfx/include \
      -I$(EXT_DIR)/bx/include \
      -I$(EXT_DIR)/bimg/include \
      -I$(EXT_DIR)/SDL/include \
      -I$(EXT_DIR)/lua-5.4.8/src \
      -I$(EXT_DIR)/sol2/include \
      -I$(EXT_DIR)/soloud20200207/include \
      -I$(EXT_DIR)/soloud20200207/src/backend/miniaudio \
      -I/usr/include/freetype2

SDL_LIB   = $(EXT_DIR)/SDL/build/libSDL3.so
FREETYPE  = -lfreetype
PTHREAD   = -lpthread
DL        = -ldl
M         = -lm

LIB_DIR = $(EXT_DIR)/lib

MAIN_OBJS = $(SRC_DIR)/main.cpp.o \
            $(SRC_DIR)/heck.cpp.o \
            $(SRC_DIR)/audio_unc.cpp.o \
            $(SRC_DIR)/ligma/ligma.cpp.o \
            $(EXT_DIR)/tsfont/font_handler.c.o

LDFLAGS = -L$(LIB_DIR) -lbimg -llu -lsoloud \
          $(SDL_LIB) \
          $(FREETYPE) $(PTHREAD) $(DL) $(M) \
          -Wl,-rpath,$(abspath $(SDL_LIB))

.PHONY: all clean test deps

all: insane_night insane_night_tests

deps:
	git submodule update --init --recursive
	git submodule sync --recursive
	mkdir -p $(EXT_DIR)
	curl -sL https://www.lua.org/ftp/lua-5.4.8.tar.gz | tar xz -C $(EXT_DIR)
	curl -sL https://solhsa.com/soloud/soloud_20200207_lite.zip -o /tmp/soloud.zip
	unzip -q -o /tmp/soloud.zip -d $(EXT_DIR)
	rm -f /tmp/soloud.zip

insane_night: $(MAIN_OBJS) $(LIB_DIR)/liblua.a $(LIB_DIR)/libsoloud.a $(LIB_DIR)/libtsfont.a
	$(CXX) $(CXXFLAGS) $^ -L$(LIB_DIR) -lbimg -lbgfx -llu -lsoloud $(SDL_LIB) $(FREETYPE) $(PTHREAD) $(DL) $(M) -Wl,-rpath,$(abspath $(SDL_LIB)) -o $@

insane_night_tests: $(TESTS_DIR)/test_logic.cpp.o
	$(CXX) $(CXXFLAGS) $(INC) $^ $(SDL_LIB) $(FREETYPE) $(PTHREAD) $(DL) $(M) -o $@

%.cpp.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INC) -c $< -o $@

%.c.o: %.c
	$(CC) $(CFLAGS) $(INC) -c $< -o $@

$(LIB_DIR)/liblua.a: $(wildcard $(EXT_DIR)/lua-5.4.8/src/*.c)
	@mkdir -p $(LIB_DIR)
	@for f in $$(ls $(EXT_DIR)/lua-5.4.8/src/*.c | grep -v /lua.c | grep -v /luac.c); do \
		$(CC) $(CFLAGS) -I$(EXT_DIR)/lua-5.4.8/src -DLUA_COMPAT_5_3 -DLUA_USE_LINUX -c $$f -o $${f%.c}.o; \
	done
	ar rcs $@ $$(ls $(EXT_DIR)/lua-5.4.8/src/*.o | grep -v /lua.c | grep -v /luac.c)

$(LIB_DIR)/libsoloud.a:
	@mkdir -p $(LIB_DIR)
	SOLOUDEPS=""; \
	for f in \
	         $(EXT_DIR)/soloud20200207/src/core/*.cpp \
	         $(EXT_DIR)/soloud20200207/src/audiosource/wav/*.cpp \
	         $(EXT_DIR)/soloud20200207/src/filter/*.cpp \
	         $(EXT_DIR)/soloud20200207/src/audiosource/wav/stb_vorbis.c \
	         $(EXT_DIR)/soloud20200207/src/backend/miniaudio/soloud_miniaudio.cpp; do \
		if [[ $$f == *.c ]]; then \
			OBJ=$${f%.c}.c.o; \
			$(CC) $(CFLAGS) -I$(EXT_DIR)/soloud20200207/include -I$(EXT_DIR)/soloud20200207/src/backend/miniaudio -DWITH_MINIAUDIO -c $$f -o $$OBJ; \
		else \
			OBJ=$${f%.cpp}.cpp.o; \
			$(CXX) $(CXXFLAGS) -I$(EXT_DIR)/soloud20200207/include -I$(EXT_DIR)/soloud20200207/src/backend/miniaudio -DWITH_MINIAUDIO -c $$f -o $$OBJ; \
		fi; \
		SOLOUDEPS="$$SOLOUDEPS $$OBJ"; \
	done; \
	ar rcs $@ $$SOLOUDEPS

$(LIB_DIR)/libtsfont.a: $(EXT_DIR)/tsfont/font_handler.c
	$(CC) $(CFLAGS) -I$(EXT_DIR)/tsfont -I/usr/include/freetype2 -c $< -o $(EXT_DIR)/tsfont/font_handler.c.o
	ar rcs $@ $(EXT_DIR)/tsfont/font_handler.c.o

test: insane_night_tests
	./insane_night_tests

clean:
	rm -f $(SRC_DIR)/*.o $(SRC_DIR)/ligma/*.o $(TESTS_DIR)/*.o
	rm -f $(EXT_DIR)/lua-5.4.8/src/*.o $(EXT_DIR)/soloud20200207/src/**/*.o $(EXT_DIR)/soloud20200207/src/**/*.c.o $(EXT_DIR)/tsfont/*.o
	rm -f insane_night insane_night_tests
