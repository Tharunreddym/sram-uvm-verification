`timescale 1ns/1ps

module sram_assertions #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 8,
  parameter int DEPTH      = (1 << ADDR_WIDTH)
)(
  input logic                  clk,
  input logic                  rst_n,
  input logic                  ce,
  input logic                  wr_en,
  input logic                  rd_en,
  input logic [ADDR_WIDTH-1:0] wr_addr,
  input logic [ADDR_WIDTH-1:0] rd_addr,
  input logic [DATA_WIDTH-1:0] wdata,
  input logic [DATA_WIDTH-1:0] rdata,
  input logic                  rvalid
);

  default clocking cb @(posedge clk); endclocking

  // 01. Write enable must only be asserted under chip enable.
  A_WR_EN_REQUIRES_CE: assert property (disable iff (!rst_n)
    wr_en |-> ce)
  else $error("wr_en asserted while ce is low");

  // 02. Read enable must only be asserted under chip enable.
  A_RD_EN_REQUIRES_CE: assert property (disable iff (!rst_n)
    rd_en |-> ce)
  else $error("rd_en asserted while ce is low");

  // 03. When chip enable is low, the interface must be idle.
  A_CE_LOW_IS_IDLE: assert property (disable iff (!rst_n)
    !ce |-> (!wr_en && !rd_en))
  else $error("ce low but operation enable is asserted");

  // 04. Same-cycle read/write to the same address is a forbidden conflict.
  A_NO_SAME_ADDR_RW_CONFLICT: assert property (disable iff (!rst_n)
    (ce && wr_en && rd_en) |-> (wr_addr != rd_addr))
  else $error("same-address read/write conflict detected");

  // 05. Read request creates output-valid one cycle later.
  A_RVALID_AFTER_READ_LATENCY: assert property (disable iff (!rst_n)
    (ce && rd_en) |=> rvalid)
  else $error("rvalid did not assert one cycle after read request");

  // 06. rvalid must only come from a previous-cycle read request.
  A_RVALID_ONLY_AFTER_READ: assert property (disable iff (!rst_n)
    rvalid |-> $past(ce && rd_en))
  else $error("rvalid asserted without previous read request");

  // 07. If there is no read request, rvalid must be low the next cycle.
  A_NO_RVALID_AFTER_NO_READ: assert property (disable iff (!rst_n)
    !(ce && rd_en) |=> !rvalid)
  else $error("rvalid asserted after a cycle with no read request");

  // 08. Outputs must be cleared after reset is sampled.
  A_RESET_CLEARS_OUTPUTS: assert property (
    !rst_n |=> (!rvalid && (rdata == '0)))
  else $error("outputs were not cleared by reset");

  // 09. Control signals must not be X/Z during active operation.
  A_CONTROLS_KNOWN: assert property (disable iff (!rst_n)
    !$isunknown({ce, wr_en, rd_en}))
  else $error("control signal contains X/Z");

  // 10. Write address must be known during writes.
  A_WR_ADDR_KNOWN_ON_WRITE: assert property (disable iff (!rst_n)
    (ce && wr_en) |-> !$isunknown(wr_addr))
  else $error("write address contains X/Z during write");

  // 11. Read address must be known during reads.
  A_RD_ADDR_KNOWN_ON_READ: assert property (disable iff (!rst_n)
    (ce && rd_en) |-> !$isunknown(rd_addr))
  else $error("read address contains X/Z during read");

  // 12. Write data must be known during writes.
  A_WDATA_KNOWN_ON_WRITE: assert property (disable iff (!rst_n)
    (ce && wr_en) |-> !$isunknown(wdata))
  else $error("write data contains X/Z during write");

  // 13. Read data must be known whenever rvalid is high.
  A_RDATA_KNOWN_WHEN_VALID: assert property (disable iff (!rst_n)
    rvalid |-> !$isunknown(rdata))
  else $error("rdata contains X/Z while rvalid is high");

  // 14. rvalid itself must never be X/Z after reset.
  A_RVALID_KNOWN: assert property (disable iff (!rst_n)
    !$isunknown(rvalid))
  else $error("rvalid contains X/Z");

  // 15. Write address must be inside configured memory depth.
  A_WR_ADDR_IN_RANGE: assert property (disable iff (!rst_n)
    (ce && wr_en) |-> (wr_addr < DEPTH))
  else $error("write address is outside configured depth");

  // 16. Read address must be inside configured memory depth.
  A_RD_ADDR_IN_RANGE: assert property (disable iff (!rst_n)
    (ce && rd_en) |-> (rd_addr < DEPTH))
  else $error("read address is outside configured depth");

  // 17. rdata must remain stable across cycles that do not issue reads.
  A_RDATA_STABLE_WITHOUT_READ: assert property (disable iff (!rst_n)
    !(ce && rd_en) |=> $stable(rdata))
  else $error("rdata changed even though no read was requested");

  // 18. Consecutive reads must keep rvalid asserted.
  A_CONSECUTIVE_READS_KEEP_RVALID: assert property (disable iff (!rst_n)
    ((ce && rd_en) && $past(ce && rd_en)) |-> rvalid)
  else $error("rvalid dropped during consecutive reads");

  // 19. A write-only operation must not create a valid read response next cycle.
  A_WRITE_ONLY_NO_NEXT_RVALID: assert property (disable iff (!rst_n)
    (ce && wr_en && !rd_en) |=> !rvalid)
  else $error("write-only operation produced rvalid");

  // 20. An idle enabled cycle must not create a valid read response next cycle.
  A_ENABLED_IDLE_NO_NEXT_RVALID: assert property (disable iff (!rst_n)
    (ce && !wr_en && !rd_en) |=> !rvalid)
  else $error("enabled idle cycle produced rvalid");

  // 21. Simultaneous read/write must have both addresses known.
  A_SIM_RW_ADDRS_KNOWN: assert property (disable iff (!rst_n)
    (ce && wr_en && rd_en) |-> !$isunknown({wr_addr, rd_addr}))
  else $error("simultaneous read/write has unknown address");

  // 22. Simultaneous read/write must have known write data.
  A_SIM_RW_WDATA_KNOWN: assert property (disable iff (!rst_n)
    (ce && wr_en && rd_en) |-> !$isunknown(wdata))
  else $error("simultaneous read/write has unknown write data");

  // 23. Read enable must not glitch into X/Z after a legal read request.
  A_RD_EN_KNOWN_AFTER_READ: assert property (disable iff (!rst_n)
    (ce && rd_en) |=> !$isunknown(rd_en))
  else $error("rd_en became unknown after read request");

  // 24. Write enable must not glitch into X/Z after a legal write request.
  A_WR_EN_KNOWN_AFTER_WRITE: assert property (disable iff (!rst_n)
    (ce && wr_en) |=> !$isunknown(wr_en))
  else $error("wr_en became unknown after write request");

  // 25. No operation is allowed with unknown chip enable.
  A_CE_KNOWN_ALWAYS: assert property (disable iff (!rst_n)
    !$isunknown(ce))
  else $error("ce contains X/Z");

endmodule
