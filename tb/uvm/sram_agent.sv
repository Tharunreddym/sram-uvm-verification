`ifndef SRAM_AGENT_SV
`define SRAM_AGENT_SV

class sram_agent extends uvm_agent;
  `uvm_component_utils(sram_agent)

  uvm_sequencer #(sram_seq_item) sequencer;
  sram_driver                   driver;
  sram_monitor                  monitor;

  function new(string name = "sram_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    monitor = sram_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = uvm_sequencer #(sram_seq_item)::type_id::create("sequencer", this);
      driver    = sram_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass

`endif
