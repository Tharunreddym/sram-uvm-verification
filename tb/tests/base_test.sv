`ifndef BASE_TEST_SV
`define BASE_TEST_SV

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  sram_env env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = sram_env::type_id::create("env", this);
  endfunction

  task wait_cycles(int unsigned cycles = 1);
    virtual sram_if #(`SRAM_DATA_WIDTH, `SRAM_ADDR_WIDTH) vif;
    if (!uvm_config_db#(virtual sram_if #(`SRAM_DATA_WIDTH, `SRAM_ADDR_WIDTH))::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "base_test failed to get virtual interface")
    end
    repeat (cycles) @(posedge vif.clk);
  endtask

  task run_phase(uvm_phase phase);
    sram_write_all_seq write_all;
    sram_read_all_seq  read_all;

    phase.raise_objection(this);
    wait_cycles(8);

    write_all = sram_write_all_seq::type_id::create("write_all");
    read_all  = sram_read_all_seq::type_id::create("read_all");

    write_all.start(env.agent.sequencer);
    read_all.start(env.agent.sequencer);

    wait_cycles(10);
    phase.drop_objection(this);
  endtask
endclass

`endif
