`timescale 1ns/1ps
`ifndef SRAM_DEFINES_SVH
`define SRAM_DEFINES_SVH
`define SRAM_DATA_WIDTH 32
`define SRAM_ADDR_WIDTH 8
`define SRAM_DEPTH      (1 << `SRAM_ADDR_WIDTH)
`endif

`include "uvm_macros.svh"

package sram_pkg;
  import uvm_pkg::*;

  // ============================================================
  // tb/uvm/sram_seq_item.sv
  // ============================================================
`ifndef SRAM_SEQ_ITEM_SV
`define SRAM_SEQ_ITEM_SV

class sram_seq_item extends uvm_sequence_item;
  rand bit                         ce;
  rand bit                         wr_en;
  rand bit                         rd_en;
  rand bit [`SRAM_ADDR_WIDTH-1:0]  wr_addr;
  rand bit [`SRAM_ADDR_WIDTH-1:0]  rd_addr;
  rand bit [`SRAM_DATA_WIDTH-1:0]  wdata;

  bit      [`SRAM_DATA_WIDTH-1:0]  rdata;
  bit                              rvalid;

  constraint legal_enable_c {
    ce dist {1'b1 := 95, 1'b0 := 5};
    if (!ce) {
      wr_en == 1'b0;
      rd_en == 1'b0;
    }
  }

  constraint useful_operation_c {
    ce -> (wr_en || rd_en);
  }

  constraint no_same_address_rw_conflict_c {
    (ce && wr_en && rd_en) -> (wr_addr != rd_addr);
  }

  `uvm_object_utils_begin(sram_seq_item)
    `uvm_field_int(ce,      UVM_ALL_ON)
    `uvm_field_int(wr_en,   UVM_ALL_ON)
    `uvm_field_int(rd_en,   UVM_ALL_ON)
    `uvm_field_int(wr_addr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(rd_addr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(wdata,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(rdata,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(rvalid,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "sram_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("ce=%0b wr_en=%0b rd_en=%0b wr_addr=0x%0h rd_addr=0x%0h wdata=0x%0h rvalid=%0b rdata=0x%0h",
                     ce, wr_en, rd_en, wr_addr, rd_addr, wdata, rvalid, rdata);
  endfunction
endclass

`endif

  // ============================================================
  // tb/uvm/sram_driver.sv
  // ============================================================
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

  // ============================================================
  // tb/uvm/sram_monitor.sv
  // ============================================================
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

  // ============================================================
  // tb/uvm/sram_scoreboard.sv
  // ============================================================
`ifndef SRAM_SCOREBOARD_SV
`define SRAM_SCOREBOARD_SV

class sram_scoreboard extends uvm_component;
  `uvm_component_utils(sram_scoreboard)

  uvm_analysis_imp #(sram_seq_item, sram_scoreboard) analysis_export;

  bit [`SRAM_DATA_WIDTH-1:0] shadow_mem [0:`SRAM_DEPTH-1];
  bit                        pending_valid;
  bit [`SRAM_DATA_WIDTH-1:0] pending_rdata;
  bit [`SRAM_ADDR_WIDTH-1:0] pending_addr;

  int unsigned total_writes;
  int unsigned total_reads;
  int unsigned matched_reads;
  int unsigned protocol_errors;
  int unsigned data_errors;

  function new(string name = "sram_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    reset_model();
  endfunction

  function void reset_model();
    foreach (shadow_mem[i]) begin
      shadow_mem[i] = '0;
    end
    pending_valid   = 1'b0;
    pending_rdata   = '0;
    pending_addr    = '0;
    total_writes    = 0;
    total_reads     = 0;
    matched_reads   = 0;
    protocol_errors = 0;
    data_errors     = 0;
  endfunction

  function void write(sram_seq_item tr);
    bit                        next_pending_valid;
    bit [`SRAM_DATA_WIDTH-1:0] next_pending_rdata;
    bit [`SRAM_ADDR_WIDTH-1:0] next_pending_addr;

    // Check the response for the read request sampled one cycle earlier.
    if (tr.rvalid !== pending_valid) begin
      protocol_errors++;
      `uvm_error("SB_RVALID", $sformatf("rvalid mismatch. expected=%0b actual=%0b pending_addr=0x%0h tr=%s",
                                         pending_valid, tr.rvalid, pending_addr, tr.convert2string()))
    end

    if (pending_valid && tr.rvalid) begin
      if (tr.rdata !== pending_rdata) begin
        data_errors++;
        `uvm_error("SB_DATA", $sformatf("Read data mismatch at addr=0x%0h expected=0x%0h actual=0x%0h tr=%s",
                                        pending_addr, pending_rdata, tr.rdata, tr.convert2string()))
      end else begin
        matched_reads++;
        `uvm_info("SB_MATCH", $sformatf("Read matched addr=0x%0h data=0x%0h", pending_addr, tr.rdata), UVM_MEDIUM)
      end
    end

    // Create next expected response before applying this cycle's write, which
    // models old-data read behavior on same-cycle read/write.
    next_pending_valid = tr.ce && tr.rd_en;
    next_pending_addr  = tr.rd_addr;
    next_pending_rdata = shadow_mem[tr.rd_addr];

    if (tr.ce && tr.rd_en) begin
      total_reads++;
    end

    if (tr.ce && tr.wr_en) begin
      shadow_mem[tr.wr_addr] = tr.wdata;
      total_writes++;
      `uvm_info("SB_WRITE", $sformatf("Shadow write addr=0x%0h data=0x%0h", tr.wr_addr, tr.wdata), UVM_HIGH)
    end

    pending_valid = next_pending_valid;
    pending_addr  = next_pending_addr;
    pending_rdata = next_pending_rdata;
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB_SUMMARY", $sformatf("writes=%0d reads=%0d matched_reads=%0d protocol_errors=%0d data_errors=%0d",
                                      total_writes, total_reads, matched_reads, protocol_errors, data_errors), UVM_LOW)
    if (protocol_errors != 0 || data_errors != 0) begin
      `uvm_error("SB_FINAL", "Scoreboard completed with errors")
    end
  endfunction
endclass

`endif

  // ============================================================
  // tb/uvm/sram_coverage.sv
  // ============================================================
`ifndef SRAM_COVERAGE_SV
`define SRAM_COVERAGE_SV

class sram_coverage extends uvm_subscriber #(sram_seq_item);
  `uvm_component_utils(sram_coverage)

  localparam int unsigned MAX_ADDR = `SRAM_DEPTH - 1;

  bit                        sample_ce;
  bit                        sample_wr_en;
  bit                        sample_rd_en;
  bit [`SRAM_ADDR_WIDTH-1:0] sample_wr_addr;
  bit [`SRAM_ADDR_WIDTH-1:0] sample_rd_addr;
  bit [`SRAM_DATA_WIDTH-1:0] sample_wdata;
  int unsigned               sample_op;

  bit                        prev_valid;
  bit                        prev_ce;
  bit                        prev_wr_en;
  bit                        prev_rd_en;
  bit [`SRAM_ADDR_WIDTH-1:0] prev_wr_addr;
  bit [`SRAM_ADDR_WIDTH-1:0] prev_rd_addr;

  bit                        b2b_same_address;
  bit                        write_then_immediate_read;
  bit                        simultaneous_read_write;
  bit                        simultaneous_read_write_boundary;

  covergroup sram_cg;
    option.per_instance = 1;

    cp_operation: coverpoint sample_op iff (sample_ce) {
      bins read_only  = {1};
      bins write_only = {2};
      bins sim_rw     = {3};
    }

    cp_wr_addr: coverpoint sample_wr_addr iff (sample_ce && sample_wr_en) {
      bins low       = {0};
      bins high      = {MAX_ADDR};
      bins low_plus  = {1};
      bins high_minus = {MAX_ADDR-1};
      bins middle[]  = {[2:MAX_ADDR-2]};
    }

    cp_rd_addr: coverpoint sample_rd_addr iff (sample_ce && sample_rd_en) {
      bins low       = {0};
      bins high      = {MAX_ADDR};
      bins low_plus  = {1};
      bins high_minus = {MAX_ADDR-1};
      bins middle[]  = {[2:MAX_ADDR-2]};
    }

    cp_wdata_patterns: coverpoint sample_wdata iff (sample_ce && sample_wr_en) {
      bins zeroes = {'0};
      bins ones   = {'1};
      bins other  = default;
    }

    cross_operation_wr_addr: cross cp_operation, cp_wr_addr;
    cross_operation_rd_addr: cross cp_operation, cp_rd_addr;
  endgroup

  covergroup temporal_cg;
    option.per_instance = 1;

    cp_b2b_same_address: coverpoint b2b_same_address {
      bins hit = {1};
    }

    cp_write_then_immediate_read: coverpoint write_then_immediate_read {
      bins hit = {1};
    }

    cp_simultaneous_read_write: coverpoint simultaneous_read_write {
      bins hit = {1};
    }

    cp_simultaneous_read_write_boundary: coverpoint simultaneous_read_write_boundary {
      bins hit = {1};
    }
  endgroup

  function new(string name = "sram_coverage", uvm_component parent = null);
    super.new(name, parent);
    sram_cg     = new();
    temporal_cg = new();
  endfunction

  function void write(sram_seq_item t);
    sram_seq_item tr;
    tr = t;
    sample_ce      = tr.ce;
    sample_wr_en   = tr.wr_en;
    sample_rd_en   = tr.rd_en;
    sample_wr_addr = tr.wr_addr;
    sample_rd_addr = tr.rd_addr;
    sample_wdata   = tr.wdata;
    sample_op      = {tr.wr_en, tr.rd_en};

    b2b_same_address = prev_valid && prev_ce && tr.ce &&
                       (prev_wr_en || prev_rd_en) && (tr.wr_en || tr.rd_en) &&
                       (((prev_wr_en ? prev_wr_addr : prev_rd_addr) == tr.wr_addr) ||
                        ((prev_wr_en ? prev_wr_addr : prev_rd_addr) == tr.rd_addr));

    write_then_immediate_read = prev_valid && prev_ce && prev_wr_en &&
                                tr.ce && tr.rd_en && (prev_wr_addr == tr.rd_addr);

    simultaneous_read_write = tr.ce && tr.wr_en && tr.rd_en && (tr.wr_addr != tr.rd_addr);

    simultaneous_read_write_boundary = simultaneous_read_write &&
                                       ((tr.wr_addr == '0) || (tr.wr_addr == MAX_ADDR) ||
                                        (tr.rd_addr == '0) || (tr.rd_addr == MAX_ADDR));

    sram_cg.sample();
    temporal_cg.sample();

    prev_valid   = 1'b1;
    prev_ce      = tr.ce;
    prev_wr_en   = tr.wr_en;
    prev_rd_en   = tr.rd_en;
    prev_wr_addr = tr.wr_addr;
    prev_rd_addr = tr.rd_addr;
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV_SUMMARY", $sformatf("functional_coverage=%0.2f%% sram_cg=%0.2f%% temporal_cg=%0.2f%%",
                                      ((sram_cg.get_inst_coverage() + temporal_cg.get_inst_coverage()) / 2.0),
                                      sram_cg.get_inst_coverage(), temporal_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif

  // ============================================================
  // tb/uvm/sram_agent.sv
  // ============================================================
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

  // ============================================================
  // tb/uvm/sram_env.sv
  // ============================================================
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

  // ============================================================
  // tb/uvm/sram_sequences.sv
  // ============================================================
`ifndef SRAM_SEQUENCES_SV
`define SRAM_SEQUENCES_SV

class sram_base_seq extends uvm_sequence #(sram_seq_item);
  `uvm_object_utils(sram_base_seq)

  function new(string name = "sram_base_seq");
    super.new(name);
  endfunction

  task body();
  endtask

  task do_idle(int unsigned cycles = 1);
    repeat (cycles) begin
      sram_seq_item tr = sram_seq_item::type_id::create("idle_tr");
      start_item(tr);
      tr.ce      = 1'b0;
      tr.wr_en   = 1'b0;
      tr.rd_en   = 1'b0;
      tr.wr_addr = '0;
      tr.rd_addr = '0;
      tr.wdata   = '0;
      finish_item(tr);
    end
  endtask

  task do_write(bit [`SRAM_ADDR_WIDTH-1:0] addr,
                bit [`SRAM_DATA_WIDTH-1:0] data);
    sram_seq_item tr = sram_seq_item::type_id::create("write_tr");
    start_item(tr);
    tr.ce      = 1'b1;
    tr.wr_en   = 1'b1;
    tr.rd_en   = 1'b0;
    tr.wr_addr = addr;
    tr.rd_addr = '0;
    tr.wdata   = data;
    finish_item(tr);
  endtask

  task do_read(bit [`SRAM_ADDR_WIDTH-1:0] addr);
    sram_seq_item tr = sram_seq_item::type_id::create("read_tr");
    start_item(tr);
    tr.ce      = 1'b1;
    tr.wr_en   = 1'b0;
    tr.rd_en   = 1'b1;
    tr.wr_addr = '0;
    tr.rd_addr = addr;
    tr.wdata   = '0;
    finish_item(tr);
  endtask

  task do_simultaneous_read_write(bit [`SRAM_ADDR_WIDTH-1:0] wr_addr,
                                  bit [`SRAM_ADDR_WIDTH-1:0] rd_addr,
                                  bit [`SRAM_DATA_WIDTH-1:0] data);
    sram_seq_item tr = sram_seq_item::type_id::create("sim_rw_tr");
    if (wr_addr == rd_addr) begin
      rd_addr = rd_addr + 1'b1;
    end
    start_item(tr);
    tr.ce      = 1'b1;
    tr.wr_en   = 1'b1;
    tr.rd_en   = 1'b1;
    tr.wr_addr = wr_addr;
    tr.rd_addr = rd_addr;
    tr.wdata   = data;
    finish_item(tr);
  endtask
endclass

class sram_write_all_seq extends sram_base_seq;
  `uvm_object_utils(sram_write_all_seq)

  function new(string name = "sram_write_all_seq");
    super.new(name);
  endfunction

  task body();
    for (int unsigned addr = 0; addr < `SRAM_DEPTH; addr++) begin
      do_write(addr[`SRAM_ADDR_WIDTH-1:0], {16'hA5A5, addr[15:0]});
    end
  endtask
endclass

class sram_read_all_seq extends sram_base_seq;
  `uvm_object_utils(sram_read_all_seq)

  function new(string name = "sram_read_all_seq");
    super.new(name);
  endfunction

  task body();
    for (int unsigned addr = 0; addr < `SRAM_DEPTH; addr++) begin
      do_read(addr[`SRAM_ADDR_WIDTH-1:0]);
    end
    do_idle(2);
  endtask
endclass

class sram_random_seq extends sram_base_seq;
  `uvm_object_utils(sram_random_seq)

  rand int unsigned num_items;

  constraint num_items_c {
    num_items inside {[250:500]};
  }

  function new(string name = "sram_random_seq");
    super.new(name);
  endfunction

  task body();
    sram_seq_item tr;

    if (!randomize()) begin
      `uvm_error("RANDSEQ", "Failed to randomize sram_random_seq")
      num_items = 300;
    end

    repeat (num_items) begin
      tr = sram_seq_item::type_id::create("random_tr");
      start_item(tr);
      if (!tr.randomize() with {
        ce    == 1'b1;
        wr_en dist {1'b1 := 55, 1'b0 := 45};
        rd_en dist {1'b1 := 55, 1'b0 := 45};
        wr_en || rd_en;
        if (wr_en && rd_en) wr_addr != rd_addr;
      }) begin
        `uvm_error("RANDITEM", "Failed to randomize SRAM transaction")
      end
      finish_item(tr);
    end
    do_idle(2);
  endtask
endclass

class sram_boundary_addr_stress_seq extends sram_base_seq;
  `uvm_object_utils(sram_boundary_addr_stress_seq)

  localparam bit [`SRAM_ADDR_WIDTH-1:0] LOW_ADDR       = '0;
  localparam bit [`SRAM_ADDR_WIDTH-1:0] LOW_PLUS_ADDR  = {{(`SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam bit [`SRAM_ADDR_WIDTH-1:0] HIGH_ADDR      = `SRAM_ADDR_WIDTH'(`SRAM_DEPTH-1);
  localparam bit [`SRAM_ADDR_WIDTH-1:0] HIGH_MINUS_ADDR = `SRAM_ADDR_WIDTH'(`SRAM_DEPTH-2);

  function new(string name = "sram_boundary_addr_stress_seq");
    super.new(name);
  endfunction

  task body();
    repeat (25) begin
      do_write(LOW_ADDR,        '0);
      do_read (LOW_ADDR);
      do_write(LOW_PLUS_ADDR,   '1);
      do_read (LOW_PLUS_ADDR);
      do_write(HIGH_MINUS_ADDR, 32'h5A5A_5A5A);
      do_read (HIGH_MINUS_ADDR);
      do_write(HIGH_ADDR,      32'hCAFE_BABE);
      do_read (HIGH_ADDR);
      do_simultaneous_read_write(LOW_ADDR, HIGH_ADDR, 32'hFACE_0001);
      do_simultaneous_read_write(HIGH_ADDR, LOW_ADDR, 32'hFACE_0002);
    end
    do_idle(2);
  endtask
endclass

class sram_simultaneous_rw_seq extends sram_base_seq;
  `uvm_object_utils(sram_simultaneous_rw_seq)

  function new(string name = "sram_simultaneous_rw_seq");
    super.new(name);
  endfunction

  task body();
    bit [`SRAM_ADDR_WIDTH-1:0] waddr;
    bit [`SRAM_ADDR_WIDTH-1:0] raddr;
    bit [`SRAM_DATA_WIDTH-1:0] data;

    for (int unsigned addr = 0; addr < `SRAM_DEPTH; addr++) begin
      do_write(addr[`SRAM_ADDR_WIDTH-1:0], 32'h1000_0000 + addr);
    end

    repeat (150) begin
      waddr = $urandom_range(0, `SRAM_DEPTH-1);
      raddr = $urandom_range(0, `SRAM_DEPTH-1);
      if (waddr == raddr) begin
        raddr = raddr + 1'b1;
      end
      data = $urandom();
      do_simultaneous_read_write(waddr, raddr, data);
    end
    do_idle(2);
  endtask
endclass

class sram_corner_case_seq extends sram_base_seq;
  `uvm_object_utils(sram_corner_case_seq)

  localparam bit [`SRAM_ADDR_WIDTH-1:0] LOW_ADDR  = '0;
  localparam bit [`SRAM_ADDR_WIDTH-1:0] HIGH_ADDR = `SRAM_ADDR_WIDTH'(`SRAM_DEPTH-1);
  localparam bit [`SRAM_ADDR_WIDTH-1:0] MID_ADDR  = `SRAM_ADDR_WIDTH'(`SRAM_DEPTH/2);

  function new(string name = "sram_corner_case_seq");
    super.new(name);
  endfunction

  task body();
    // Boundary address stress.
    do_write(LOW_ADDR,  32'h0000_0000);
    do_read (LOW_ADDR);
    do_write(HIGH_ADDR, 32'hFFFF_FFFF);
    do_read (HIGH_ADDR);

    // Back-to-back same-address writes, then immediate reads.
    do_write(MID_ADDR, 32'h1111_1111);
    do_write(MID_ADDR, 32'h2222_2222);
    do_read (MID_ADDR);
    do_read (MID_ADDR);

    // Write then immediate read to the same address.
    do_write(LOW_ADDR, 32'hABCD_1234);
    do_read (LOW_ADDR);

    // Legal simultaneous read/write injection with different addresses.
    repeat (50) begin
      do_simultaneous_read_write(LOW_ADDR,  HIGH_ADDR, $urandom());
      do_simultaneous_read_write(HIGH_ADDR, LOW_ADDR,  $urandom());
    end

    // Random corner mixing.
    repeat (100) begin
      bit [`SRAM_ADDR_WIDTH-1:0] addr;
      addr = $urandom_range(0, `SRAM_DEPTH-1);
      do_write(addr, $urandom());
      do_read(addr);
    end
    do_idle(2);
  endtask
endclass

`endif

  // ============================================================
  // tb/tests/base_test.sv
  // ============================================================
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

  // ============================================================
  // tb/tests/random_test.sv
  // ============================================================
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

  // ============================================================
  // tb/tests/corner_case_test.sv
  // ============================================================
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

endpackage

// ============================================================
// tb/top.sv
// ============================================================
module tb_top;
  import uvm_pkg::*;
  import sram_pkg::*;

  localparam int DATA_WIDTH = `SRAM_DATA_WIDTH;
  localparam int ADDR_WIDTH = `SRAM_ADDR_WIDTH;
  localparam int DEPTH      = `SRAM_DEPTH;

  logic clk;
  logic rst_n;

  sram_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) sram_vif (
    .clk   (clk),
    .rst_n (rst_n)
  );

  sram_ctrl #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DEPTH     (DEPTH)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .ce      (sram_vif.ce),
    .wr_en   (sram_vif.wr_en),
    .rd_en   (sram_vif.rd_en),
    .wr_addr (sram_vif.wr_addr),
    .rd_addr (sram_vif.rd_addr),
    .wdata   (sram_vif.wdata),
    .rdata   (sram_vif.rdata),
    .rvalid  (sram_vif.rvalid)
  );

  sram_assertions #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DEPTH     (DEPTH)
  ) sva (
    .clk     (clk),
    .rst_n   (rst_n),
    .ce      (sram_vif.ce),
    .wr_en   (sram_vif.wr_en),
    .rd_en   (sram_vif.rd_en),
    .wr_addr (sram_vif.wr_addr),
    .rd_addr (sram_vif.rd_addr),
    .wdata   (sram_vif.wdata),
    .rdata   (sram_vif.rdata),
    .rvalid  (sram_vif.rvalid)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual sram_if #(DATA_WIDTH, ADDR_WIDTH))::set(null, "*", "vif", sram_vif);
    run_test();
  end

  initial begin
    #5ms;
    $fatal(1, "Simulation timeout reached");
  end
endmodule
