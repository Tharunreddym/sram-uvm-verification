`timescale 1ns/1ps

interface sram_if #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 8
)(
  input logic clk,
  input logic rst_n
);

  logic                  ce;
  logic                  wr_en;
  logic                  rd_en;
  logic [ADDR_WIDTH-1:0] wr_addr;
  logic [ADDR_WIDTH-1:0] rd_addr;
  logic [DATA_WIDTH-1:0] wdata;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  rvalid;

  clocking drv_cb @(posedge clk);
    default input #1step output #1ns;
    output ce;
    output wr_en;
    output rd_en;
    output wr_addr;
    output rd_addr;
    output wdata;
    input  rdata;
    input  rvalid;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step output #1step;
    input ce;
    input wr_en;
    input rd_en;
    input wr_addr;
    input rd_addr;
    input wdata;
    input rdata;
    input rvalid;
  endclocking

  modport DRV (clocking drv_cb, input clk, input rst_n);
  modport MON (clocking mon_cb, input clk, input rst_n);

endinterface
