EDA Playground paste instructions

1. In EDA Playground, clear the Design pane completely.
2. Paste the contents of 01_PASTE_IN_DESIGN_PANE_design.sv into the Design pane.
   The Design pane must contain module sram_ctrl, interface sram_if, and module sram_assertions.
   It must NOT contain package sram_pkg or module tb_top.

3. Clear the Testbench pane completely.
4. Paste the contents of 02_PASTE_IN_TESTBENCH_PANE_testbench.sv into the Testbench pane.
   The Testbench pane must contain package sram_pkg and module tb_top.

Settings:
Language: SystemVerilog/Verilog
Library: UVM 1.2
Simulator: Questa/QuestaSim
Top entity: tb_top

Run options:
+UVM_TESTNAME=base_test +UVM_VERBOSITY=UVM_MEDIUM -sv_seed 1

Good compile log should include:
-- Compiling module sram_ctrl
-- Compiling interface sram_if
-- Compiling module sram_assertions
-- Compiling package sram_pkg
-- Compiling module tb_top

It should NOT show:
Existing package 'sram_pkg' ... will be overwritten
Existing module 'tb_top' ... will be overwritten
