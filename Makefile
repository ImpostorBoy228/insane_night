CC      ?= gcc
CXX     ?= g++
CFLAGS  = -std=c17 -O3 -DNDEBUG -DBX_CONFIG_DEBUG=0 -flto
CXXFLAGS= -std=gnu++26 -O3 -DNDEBUG -DBX_CONFIG_DEBUG=0 -flto

JOBS ?= $(shell nproc 2>/dev/null || echo 4)

ifeq (,$(strip $(filter -j% j%,$(MAKEFLAGS))$(findstring --jobserver,$(MAKEFLAGS))))
MAKEFLAGS += -j$(JOBS)
endif

SRC_DIR   = src
EXT_DIR   = external
TESTS_DIR = tests(vibecoded)/cpp

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

SDL_RPATH = -Wl,-rpath,$(abspath $(dir $(SDL_LIB)))

LDFLAGS = $(LTO_LINK) -L$(LIB_DIR) -Wl,--start-group -lbimg -lbgfx -lbx -llua -lsoloud -Wl,--end-group \
          $(SDL_LIB) \
          $(FREETYPE) $(PTHREAD) $(DL) $(M) \
          $(SDL_RPATH)

LTO_LINK ?= -flto=$(JOBS)

SHADERS_DIR = src/shaders
BGFX_INC    = external/bgfx/src
SHADERC     = external/bgfx/tools/bin/linux/shaderc

VS_SOURCES = $(wildcard $(SHADERS_DIR)/vs_*.sc)
FS_SOURCES = $(wildcard $(SHADERS_DIR)/fs_*.sc)
VS_OUTPUTS = $(VS_SOURCES:.sc=.bin.h)
FS_OUTPUTS = $(FS_SOURCES:.sc=.bin.h)
ALL_SHADER_OUTPUTS = $(VS_OUTPUTS) $(FS_OUTPUTS)

.DEFAULT_GOAL := all
.PHONY: FORCE # 😈😈😈
FORCE:

.PHONY: all clean tests deps bgfx shaders clean-shaders rebuild

all: insane_night

deps:
	git submodule update --init --recursive
	git submodule sync --recursive
	mkdir -p $(EXT_DIR)
	curl -sL https://www.lua.org/ftp/lua-5.4.8.tar.gz | tar xz -C $(EXT_DIR)
	curl -sL https://solhsa.com/soloud/soloud_20200207_lite.zip -o /tmp/soloud.zip
	unzip -q -o /tmp/soloud.zip -d $(EXT_DIR)
	rm -f /tmp/soloud.zip

BGFX_BIN  = $(EXT_DIR)/bgfx/.build/linux64_gcc/bin
BGFX_PROJ = $(EXT_DIR)/bgfx/.build/projects/gmake-linux-gcc
BGFX_LIBS = bx bgfx bimg

bgfx:
	@mkdir -p $(LIB_DIR)
	+$(MAKE) -C $(EXT_DIR)/bgfx shaderc
	+$(MAKE) -C $(BGFX_PROJ) config=release64 $(BGFX_LIBS)
	@for l in $(BGFX_LIBS); do cp -f $(BGFX_BIN)/lib$${l}Release.a $(LIB_DIR)/lib$$l.a; done

insane_night: $(MAIN_OBJS) $(LIB_DIR)/liblua.a $(LIB_DIR)/libsoloud.a $(LIB_DIR)/libtsfont.a FORCE
	$(CXX) $(CXXFLAGS) $(filter-out FORCE,$^) $(LDFLAGS) -o $@

insane_night_tests: $(TESTS_DIR)/test_logic.cpp.o FORCE
	$(CXX) $(CXXFLAGS) $(INC) '$(TESTS_DIR)/test_logic.cpp.o' $(LTO_LINK) $(SDL_LIB) $(SDL_RPATH) $(FREETYPE) $(PTHREAD) $(DL) $(M) -o $@

$(SRC_DIR)/main.cpp.o $(SRC_DIR)/heck.cpp.o $(TESTS_DIR)/test_logic.cpp.o: $(ALL_SHADER_OUTPUTS)

%.cpp.o: %.cpp FORCE
	$(CXX) $(CXXFLAGS) $(INC) -c '$<' -o '$@'

%.c.o: %.c FORCE
	$(CC) $(CFLAGS) $(INC) -c '$<' -o '$@'

LUA_DIR  = $(EXT_DIR)/lua-5.4.8/src
LUA_DEFS = -DLUA_COMPAT_5_3 -DLUA_USE_LINUX
LUA_SRCS = $(filter-out $(LUA_DIR)/lua.c $(LUA_DIR)/luac.c,$(wildcard $(LUA_DIR)/*.c))
LUA_OBJS = $(LUA_SRCS:.c=.o)

$(LUA_OBJS): %.o: %.c
	$(CC) $(CFLAGS) $(LUA_DEFS) -I$(LUA_DIR) -c $< -o $@

$(LIB_DIR)/liblua.a: $(LUA_OBJS)
	@mkdir -p $(LIB_DIR)
	ar rcs $@ $^

SOLOUD_DIR  = $(EXT_DIR)/soloud20200207
SOLOUD_DEFS = -I$(SOLOUD_DIR)/include -I$(SOLOUD_DIR)/src/backend/miniaudio -DWITH_MINIAUDIO
SOLOUD_SRCS = $(wildcard $(SOLOUD_DIR)/src/core/*.cpp) \
              $(wildcard $(SOLOUD_DIR)/src/audiosource/wav/*.cpp) \
              $(wildcard $(SOLOUD_DIR)/src/filter/*.cpp) \
              $(SOLOUD_DIR)/src/backend/miniaudio/soloud_miniaudio.cpp \
              $(SOLOUD_DIR)/src/audiosource/wav/stb_vorbis.c
SOLOUD_C_SRCS   = $(filter %.c,$(SOLOUD_SRCS))
SOLOUD_CXX_SRCS = $(filter %.cpp,$(SOLOUD_SRCS))
SOLOUD_OBJS     = $(SOLOUD_CXX_SRCS:.cpp=.cpp.o) $(SOLOUD_C_SRCS:.c=.c.o)

$(SOLOUD_C_SRCS:.c=.c.o): %.c.o: %.c
	$(CC) $(CFLAGS) $(SOLOUD_DEFS) -c $< -o $@

$(SOLOUD_CXX_SRCS:.cpp=.cpp.o): %.cpp.o: %.cpp
	$(CXX) $(CXXFLAGS) $(SOLOUD_DEFS) -c $< -o $@

$(LIB_DIR)/libsoloud.a: $(SOLOUD_OBJS)
	@mkdir -p $(LIB_DIR)
	ar rcs $@ $^

$(EXT_DIR)/tsfont/font_handler.c.o: $(EXT_DIR)/tsfont/font_handler.c
	$(CC) $(CFLAGS) $(INC) -c $< -o $@

$(LIB_DIR)/libtsfont.a: $(EXT_DIR)/tsfont/font_handler.c.o
	@mkdir -p $(LIB_DIR)
	ar rcs $@ $^

$(SHADERS_DIR)/vs_%.bin.h: $(SHADERS_DIR)/vs_%.sc $(SHADERS_DIR)/varying.def.sc FORCE
	$(SHADERC) --type vertex --platform vulkan -p spirv -i $(BGFX_INC) -f $< -o $@.tmp --bin2c $(basename $(basename $(@F)))
	cat $@.tmp > $@
	rm -f $@.tmp

$(SHADERS_DIR)/fs_%.bin.h: $(SHADERS_DIR)/fs_%.sc $(SHADERS_DIR)/varying.def.sc FORCE
	$(SHADERC) --type fragment --platform vulkan -p spirv -i $(BGFX_INC) -f $< -o $@.tmp --bin2c $(basename $(basename $(@F)))
	cat $@.tmp > $@
	rm -f $@.tmp

shaders: $(ALL_SHADER_OUTPUTS)

clean-shaders:
	rm -f $(ALL_SHADER_OUTPUTS)

tests: insane_night_tests
	cd tests\(vibecoded\)/ && sh run.sh

clean: clean-shaders
	rm -f $(SRC_DIR)/*.o $(SRC_DIR)/ligma/*.o '$(TESTS_DIR)'/*.o
	find $(LUA_DIR) $(SOLOUD_DIR)/src $(EXT_DIR)/tsfont -name '*.o' -delete 2>/dev/null || true
	rm -f insane_night insane_night_tests

rebuild:
	@$(MAKE) clean
	@$(MAKE) all
