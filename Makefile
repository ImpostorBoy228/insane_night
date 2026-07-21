BUILD_DIR ?= .build
CMAKE    ?= cmake
NINJA    ?= ninja
SHADERC  ?= external/bgfx/tools/bin/linux/shaderc
ROOT     ?= $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.PHONY: all dev shaders clean

all: release

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
