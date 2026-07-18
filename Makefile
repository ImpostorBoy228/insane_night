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

clean:
	rm -rf $(BUILD_DIR) insane_night $(COMPDB) *.o *.a
	$(MAKE) -C external/lua-5.4.8/src clean 2>/dev/null; true

rebuild: clean all

.PHONY: all dev clean rebuild compdb
