`ifndef RANDOM_TEST_SV
`define RANDOM_TEST_SV

class random_test extends base_test;
  `uvm_component_utils(random_test)

  function new(string name = "random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    sram_write_all_seq       write_all;
    sram_random_seq          random_seq;
    sram_simultaneous_rw_seq sim_rw_seq;
    sram_read_all_seq        read_all;

    phase.raise_objection(this);
    wait_cycles(8);

    write_all  = sram_write_all_seq::type_id::create("write_all");
    random_seq = sram_random_seq::type_id::create("random_seq");
    sim_rw_seq = sram_simultaneous_rw_seq::type_id::create("sim_rw_seq");
    read_all   = sram_read_all_seq::type_id::create("read_all");

    write_all.start(env.agent.sequencer);
    random_seq.start(env.agent.sequencer);
    sim_rw_seq.start(env.agent.sequencer);
    read_all.start(env.agent.sequencer);

    wait_cycles(20);
    phase.drop_objection(this);
  endtask
endclass

`endif
