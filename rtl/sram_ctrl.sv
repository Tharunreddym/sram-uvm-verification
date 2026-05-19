`timescale 1ns/1ps

module sram_ctrl #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 8,
  parameter int DEPTH      = (1 << ADDR_WIDTH)
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  ce,
  input  logic                  wr_en,
  input  logic                  rd_en,
  input  logic [ADDR_WIDTH-1:0] wr_addr,
  input  logic [ADDR_WIDTH-1:0] rd_addr,
  input  logic [DATA_WIDTH-1:0] wdata,
  output logic [DATA_WIDTH-1:0] rdata,
  output logic                  rvalid
);

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  // Synchronous SRAM model:
  // - write occurs on rising edge when ce && wr_en
  // - read data is registered and valid one cycle after ce && rd_en
  // - simultaneous read/write is legal only when addresses are different
  // - same-cycle read/write to the same address returns the old value because
  //   nonblocking assignment reads the previous memory contents
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rdata  <= '0;
      rvalid <= 1'b0;
      for (int i = 0; i < DEPTH; i++) begin
        mem[i] <= '0;
      end
    end else begin
      rvalid <= ce && rd_en;

      if (ce && rd_en) begin
        rdata <= mem[rd_addr];
      end

      if (ce && wr_en) begin
        mem[wr_addr] <= wdata;
      end
    end
  end

endmodule
