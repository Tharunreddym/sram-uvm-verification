`ifndef SRAM_MONITOR_SV
`define SRAM_MONITOR_SV

class sram_monitor extends uvm_component;
  `uvm_component_utils(sram_monitor)

  virtual sram_if #(`SRAM_DATA_WIDTH, `SRAM_ADDR_WIDTH) vif;
  uvm_analysis_port #(sram_seq_item) analysis_port;

  function new(string name = "sram_monitor", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sram_if #(`SRAM_DATA_WIDTH, `SRAM_ADDR_WIDTH))::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "sram_monitor failed to get virtual interface from uvm_config_db")
    end
  endfunction

  task run_phase(uvm_phase phase);
    sram_seq_item tr;

    forever begin
      @(vif.mon_cb);

      if (vif.rst_n !== 1'b1) begin
        continue;
      end

      tr = sram_seq_item::type_id::create("tr", this);
      tr.ce      = vif.mon_cb.ce;
      tr.wr_en   = vif.mon_cb.wr_en;
      tr.rd_en   = vif.mon_cb.rd_en;
      tr.wr_addr = vif.mon_cb.wr_addr;
      tr.rd_addr = vif.mon_cb.rd_addr;
      tr.wdata   = vif.mon_cb.wdata;
      tr.rdata   = vif.mon_cb.rdata;
      tr.rvalid  = vif.mon_cb.rvalid;

      analysis_port.write(tr);
      `uvm_info("MON", {"Observed: ", tr.convert2string()}, UVM_HIGH)
    end
  endtask
endclass

`endif
