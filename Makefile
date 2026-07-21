BUILD_DIR ?= build
BUILD_TYPE ?= Release
CMAKE ?= cmake
NINJA ?= ninja
COMPDB = compile_commands.json

CMAKE_OPTS = -B $(BUILD_DIR) -G Ninja \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_BUILD_TYPE=$(BUILD_TYPE)

all: $(BUILD_DIR)/build.ninja
	$(NINJA) -C $(BUILD_DIR)
	@ln -sf $(BUILD_DIR)/$(COMPDB) $(COMPDB) 2>/dev/null; true

$(BUILD_DIR)/build.ninja: CMakeLists.txt
	$(CMAKE) $(CMAKE_OPTS)

dev: BUILD_TYPE = Debug
dev: FORCE
	$(CMAKE) $(CMAKE_OPTS)
	$(NINJA) -C $(BUILD_DIR)
	@ln -sf $(BUILD_DIR)/$(COMPDB) $(COMPDB) 2>/dev/null; true

FORCE:

compdb: $(COMPDB)

$(COMPDB): $(BUILD_DIR)/build.ninja
	@ln -sf $(BUILD_DIR)/$(COMPDB) $(COMPDB) 2>/dev/null; true

clean: clean-shaders
	rm -rf $(BUILD_DIR) insane_night $(COMPDB) *.o *.a
	$(MAKE) -C external/lua-5.4.8/src clean 2>/dev/null; true

rebuild: clean all

disassembly: insane_night
	objdump -d insane_night > insane_night.dis

SHADERS_DIR = src/shaders
BGFX_INC   = external/bgfx/src
SHADERC    = external/bgfx/tools/bin/linux/shaderc

VS_SOURCES = $(wildcard $(SHADERS_DIR)/vs_*.sc)
FS_SOURCES = $(wildcard $(SHADERS_DIR)/fs_*.sc)
VS_OUTPUTS = $(VS_SOURCES:.sc=.bin.h)
FS_OUTPUTS = $(FS_SOURCES:.sc=.bin.h)
ALL_SHADER_OUTPUTS = $(VS_OUTPUTS) $(FS_OUTPUTS)

$(SHADERS_DIR)/vs_%.bin.h: $(SHADERS_DIR)/vs_%.sc $(SHADERS_DIR)/varying.def.sc
	$(SHADERC) --type vertex --platform linux -p spirv -i $(BGFX_INC) -f $< -o $@.tmp --bin2c $(basename $(basename $(@F)))
	cat $@.tmp > $@
	rm -f $@.tmp

$(SHADERS_DIR)/fs_%.bin.h: $(SHADERS_DIR)/fs_%.sc $(SHADERS_DIR)/varying.def.sc
	$(SHADERC) --type fragment --platform linux -p spirv -i $(BGFX_INC) -f $< -o $@.tmp --bin2c $(basename $(basename $(@F)))
	cat $@.tmp > $@
	rm -f $@.tmp

.PHONY: all dev clean rebuild compdb disassembly shaders clean-shaders

shaders: $(ALL_SHADER_OUTPUTS)

clean-shaders:
	rm -f $(ALL_SHADER_OUTPUTS)
