`ifndef SRAM_PKG_SV
`define SRAM_PKG_SV

`include "sram_defines.svh"

package sram_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "sram_seq_item.sv"
  `include "sram_driver.sv"
  `include "sram_monitor.sv"
  `include "sram_scoreboard.sv"
  `include "sram_coverage.sv"
  `include "sram_agent.sv"
  `include "sram_env.sv"
  `include "sram_sequences.sv"
  `include "base_test.sv"
  `include "random_test.sv"
  `include "corner_case_test.sv"
endpackage

`endif
