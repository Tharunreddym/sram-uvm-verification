`ifndef SRAM_ENV_SV
`define SRAM_ENV_SV

class sram_env extends uvm_env;
  `uvm_component_utils(sram_env)

  sram_agent      agent;
  sram_scoreboard scoreboard;
  sram_coverage   coverage;

  function new(string name = "sram_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = sram_agent::type_id::create("agent", this);
    scoreboard = sram_scoreboard::type_id::create("scoreboard", this);
    coverage   = sram_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.analysis_port.connect(scoreboard.analysis_export);
    agent.monitor.analysis_port.connect(coverage.analysis_export);
  endfunction
endclass

`endif
