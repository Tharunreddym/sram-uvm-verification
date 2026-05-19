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
