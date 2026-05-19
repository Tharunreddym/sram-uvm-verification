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

  function void write(sram_seq_item tr);
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
