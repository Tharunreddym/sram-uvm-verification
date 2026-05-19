`ifndef SRAM_DRIVER_SV
`define SRAM_DRIVER_SV

class sram_driver extends uvm_driver #(sram_seq_item);
  `uvm_component_utils(sram_driver)

  virtual sram_if #(`SRAM_DATA_WIDTH, `SRAM_ADDR_WIDTH) vif;

  function new(string name = "sram_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sram_if #(`SRAM_DATA_WIDTH, `SRAM_ADDR_WIDTH))::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "sram_driver failed to get virtual interface from uvm_config_db")
    end
  endfunction

  task run_phase(uvm_phase phase);
    reset_bus();
    wait (vif.rst_n === 1'b1);
    @(vif.drv_cb);

    forever begin
      seq_item_port.get_next_item(req);
      drive_one(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_bus();
    vif.drv_cb.ce      <= 1'b0;
    vif.drv_cb.wr_en   <= 1'b0;
    vif.drv_cb.rd_en   <= 1'b0;
    vif.drv_cb.wr_addr <= '0;
    vif.drv_cb.rd_addr <= '0;
    vif.drv_cb.wdata   <= '0;
  endtask

  task drive_one(sram_seq_item tr);
    @(vif.drv_cb);
    vif.drv_cb.ce      <= tr.ce;
    vif.drv_cb.wr_en   <= tr.wr_en;
    vif.drv_cb.rd_en   <= tr.rd_en;
    vif.drv_cb.wr_addr <= tr.wr_addr;
    vif.drv_cb.rd_addr <= tr.rd_addr;
    vif.drv_cb.wdata   <= tr.wdata;
    `uvm_info("DRV", {"Drove: ", tr.convert2string()}, UVM_HIGH)
  endtask
endclass

`endif
