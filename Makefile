FPC ?= fpc
BUILD_DIR ?= build

.PHONY: all test clean
all:
	mkdir -p $(BUILD_DIR)/units
	$(FPC) -MObjFPC -Scghi -O2 -Fu./src -FU$(BUILD_DIR)/units -FE$(BUILD_DIR) -ombulletin src/mbulletin.lpr

test: all
	$(BUILD_DIR)/mbulletin --self-test

clean:
	rm -rf $(BUILD_DIR)
