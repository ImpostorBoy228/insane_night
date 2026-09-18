BUILD_DIR ?= .build
CMAKE    ?= cmake
NINJA    ?= ninja
SHADERC  ?= external/bgfx/tools/bin/linux/shaderc
ROOT     ?= $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

export PKG_CONFIG_PATH ?= /usr/local/lib64/pkgconfig

.PHONY: all dev shaders tests clean bgfx sdl3

all: release

bgfx:
	$(MAKE) -C external/bgfx/.build/projects/gmake-linux-gcc config=release64 bgfx bx bimg shaderc
	mkdir -p external/lib
	cp external/bgfx/.build/linux64_gcc/bin/libbgfxRelease.a external/lib/libbgfx.a
	cp external/bgfx/.build/linux64_gcc/bin/libbimgRelease.a external/lib/libbimg.a
	cp external/bgfx/.build/linux64_gcc/bin/libbxRelease.a external/lib/libbx.a
	cp external/bgfx/.build/linux64_gcc/bin/shadercRelease external/bgfx/tools/bin/linux/shaderc

sdl3:
	mkdir -p external/SDL/build
	cmake -S external/SDL -B external/SDL/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
	cmake --build external/SDL/build -j2
	sudo cmake --install external/SDL/build
	sudo ldconfig

release: shaders CMakeLists.txt
	$(CMAKE) -B $(BUILD_DIR) -G Ninja -DCMAKE_BUILD_TYPE=Release \
	  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=$(ROOT)
	$(NINJA) -C $(BUILD_DIR)
	ln -sf $(BUILD_DIR)/compile_commands.json compile_commands.json 2>/dev/null || true

dev: shaders CMakeLists.txt
	$(CMAKE) -B $(BUILD_DIR) -G Ninja -DCMAKE_BUILD_TYPE=Debug \
	  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=$(ROOT)
	$(NINJA) -C $(BUILD_DIR)
	ln -sf $(BUILD_DIR)/compile_commands.json compile_commands.json 2>/dev/null || true

tests: shaders CMakeLists.txt
	$(CMAKE) -B $(BUILD_DIR) -G Ninja -DCMAKE_BUILD_TYPE=Debug \
	  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=$(ROOT)
	$(NINJA) -C $(BUILD_DIR) insane_night_tests
	bash "tests(vibecoded)/run.sh"
	ln -sf $(BUILD_DIR)/compile_commands.json compile_commands.json 2>/dev/null || true

SHADER_INC     = -i external/bgfx/src
SHADER_VARYING = --varyingdef src/shaders/varying.def.sc
SHADER_OPTS    = --platform linux -p 120 -O 3 --bin2c

shaders:
	@for f in src/shaders/*.sc; do \
	  name=$$(basename "$$f" .sc); \
	  case "$$name" in \
	    fs_*) type=fragment ;; \
	    vs_*) type=vertex   ;; \
	    *) echo "SKIP unknown type: $$name"; continue ;; \
	  esac; \
	  echo "  SHADERC $$name"; \
	  $(SHADERC) -f "$$f" -o "src/shaders/$$name.bin.h" \
	    $(SHADER_INC) $(SHADER_VARYING) \
	    --type "$$type" $(SHADER_OPTS); \
	done

clean:
	rm -rf $(BUILD_DIR) compile_commands.json insane_night
	rm -f src/shaders/*.bin.h
	rm -f *.dis *.o
