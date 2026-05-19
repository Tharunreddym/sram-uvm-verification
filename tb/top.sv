`timescale 1ns/1ps
`include "sram_defines.svh"
`include "uvm_macros.svh"

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
