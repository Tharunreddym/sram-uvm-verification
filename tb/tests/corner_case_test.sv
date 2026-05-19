`ifndef CORNER_CASE_TEST_SV
`define CORNER_CASE_TEST_SV

class corner_case_test extends base_test;
  `uvm_component_utils(corner_case_test)

  function new(string name = "corner_case_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    sram_boundary_addr_stress_seq boundary_seq;
    sram_corner_case_seq          corner_seq;
    sram_read_all_seq             read_all;

    phase.raise_objection(this);
    wait_cycles(8);

    boundary_seq = sram_boundary_addr_stress_seq::type_id::create("boundary_seq");
    corner_seq   = sram_corner_case_seq::type_id::create("corner_seq");
    read_all     = sram_read_all_seq::type_id::create("read_all");

    boundary_seq.start(env.agent.sequencer);
    corner_seq.start(env.agent.sequencer);
    read_all.start(env.agent.sequencer);

    wait_cycles(20);
    phase.drop_objection(this);
  endtask
endclass

`endif
