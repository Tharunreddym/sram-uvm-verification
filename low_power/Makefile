IVERILOG ?= iverilog
VVP ?= vvp
BUILD_DIR ?= build

.PHONY: test clean

test: $(BUILD_DIR)/sram_banked_ctrl_lp_tb
	$(VVP) $<

$(BUILD_DIR)/sram_banked_ctrl_lp_tb: sram_banked_ctrl_lp.sv tb/sram_banked_ctrl_lp_tb.sv
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -s sram_banked_ctrl_lp_tb -o $@ $^

clean:
	rm -rf $(BUILD_DIR)
