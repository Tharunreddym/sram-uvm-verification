// Bank-aware low-power SRAM controller example.
// Each bank has an independently gated clock and ACTIVE/SLEEP/WAKE state.
// The behavioral memory array retains contents while its bank clock is stopped.

module sram_icg (
  input  logic clk,
  input  logic enable,
  input  logic test_enable,
  output logic gclk
);
  logic enable_latched;
  always_latch begin
    if (!clk)
      enable_latched <= enable || test_enable;
  end
  assign gclk = clk && enable_latched;
endmodule

module sram_bank_power_ctrl #(
  parameter integer NUM_BANKS = 4,
  parameter integer BANK_INDEX_WIDTH = (NUM_BANKS <= 1) ? 1 : $clog2(NUM_BANKS),
  parameter integer IDLE_CYCLES = 8,
  parameter integer WAKEUP_CYCLES = 2,
  parameter integer COUNTER_WIDTH = (IDLE_CYCLES > WAKEUP_CYCLES) ?
                                    $clog2(IDLE_CYCLES + 1) : $clog2(WAKEUP_CYCLES + 1)
) (
  input  logic clk,
  input  logic rst_n,
  input  logic req_valid,
  input  logic [BANK_INDEX_WIDTH-1:0] req_bank,
  output logic req_ready,
  output logic [NUM_BANKS-1:0] bank_clk_en,
  output logic [NUM_BANKS-1:0] bank_sleep,
  output logic [NUM_BANKS-1:0] retention_save,
  output logic [NUM_BANKS-1:0] retention_restore
);
  localparam logic [1:0] BANK_ACTIVE = 2'd0;
  localparam logic [1:0] BANK_SLEEP  = 2'd1;
  localparam logic [1:0] BANK_WAKE   = 2'd2;

  logic [1:0] bank_state [0:NUM_BANKS-1];
  logic [COUNTER_WIDTH-1:0] idle_count [0:NUM_BANKS-1];
  logic [COUNTER_WIDTH-1:0] wake_count [0:NUM_BANKS-1];
  integer i;

  always_comb begin
    req_ready = 1'b0;
    if (req_bank < NUM_BANKS)
      req_ready = (bank_state[req_bank] == BANK_ACTIVE);

    for (integer b = 0; b < NUM_BANKS; b = b + 1) begin
      bank_sleep[b] = (bank_state[b] == BANK_SLEEP);
      // Clock only a bank that is restoring or accepting a real request.
      bank_clk_en[b] = (bank_state[b] == BANK_WAKE) ||
                       ((bank_state[b] == BANK_ACTIVE) &&
                        req_valid && (req_bank == b));
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      retention_save    <= '0;
      retention_restore <= '0;
      for (i = 0; i < NUM_BANKS; i = i + 1) begin
        bank_state[i] <= BANK_ACTIVE;
        idle_count[i] <= '0;
        wake_count[i] <= '0;
      end
    end else begin
      retention_save    <= '0;
      retention_restore <= '0;

      for (i = 0; i < NUM_BANKS; i = i + 1) begin
        case (bank_state[i])
          BANK_ACTIVE: begin
            wake_count[i] <= '0;
            if (req_valid && (req_bank == i)) begin
              idle_count[i] <= '0;
            end else if (IDLE_CYCLES <= 1 ||
                         idle_count[i] >= IDLE_CYCLES - 1) begin
              bank_state[i]   <= BANK_SLEEP;
              idle_count[i]   <= '0;
              retention_save[i] <= 1'b1;
            end else begin
              idle_count[i] <= idle_count[i] + 1'b1;
            end
          end

          BANK_SLEEP: begin
            if (req_valid && (req_bank == i)) begin
              bank_state[i] <= BANK_WAKE;
              wake_count[i] <= '0;
              retention_restore[i] <= 1'b1;
            end
          end

          BANK_WAKE: begin
            if (WAKEUP_CYCLES <= 1 ||
                wake_count[i] >= WAKEUP_CYCLES - 1) begin
              bank_state[i] <= BANK_ACTIVE;
              wake_count[i] <= '0;
              idle_count[i] <= '0;
            end else begin
              wake_count[i] <= wake_count[i] + 1'b1;
            end
          end

          default: begin
            bank_state[i] <= BANK_ACTIVE;
            idle_count[i] <= '0;
            wake_count[i] <= '0;
          end
        endcase
      end
    end
  end
endmodule

module sram_banked_ctrl_lp #(
  parameter integer DATA_WIDTH = 32,
  parameter integer ADDR_WIDTH = 8,
  parameter integer NUM_BANKS = 4,
  parameter integer IDLE_CYCLES = 8,
  parameter integer WAKEUP_CYCLES = 2,
  parameter integer BANK_INDEX_WIDTH = (NUM_BANKS <= 1) ? 1 : $clog2(NUM_BANKS),
  parameter integer ROW_WIDTH = ADDR_WIDTH - BANK_INDEX_WIDTH,
  parameter integer BANK_DEPTH = (1 << ROW_WIDTH)
) (
  input  logic clk,
  input  logic rst_n,
  input  logic req_valid,
  input  logic [BANK_INDEX_WIDTH-1:0] req_bank,
  input  logic [ROW_WIDTH-1:0] req_row,
  input  logic rd_en,
  input  logic wr_en,
  input  logic [DATA_WIDTH-1:0] wdata,
  output wire [DATA_WIDTH-1:0] rdata,
  output logic rvalid,
  output logic req_ready,
  output logic [NUM_BANKS-1:0] bank_sleep,
  output logic [NUM_BANKS-1:0] bank_clk_en,
  output logic [NUM_BANKS-1:0] retention_save,
  output logic [NUM_BANKS-1:0] retention_restore
);
  logic [NUM_BANKS-1:0] bank_clk;
  logic [DATA_WIDTH-1:0] mem [0:NUM_BANKS-1][0:BANK_DEPTH-1];
  logic [DATA_WIDTH-1:0] bank_rdata [0:NUM_BANKS-1];
  logic [BANK_INDEX_WIDTH-1:0] last_read_bank;
  integer init_bank, init_row;

  sram_bank_power_ctrl #(
    .NUM_BANKS(NUM_BANKS),
    .BANK_INDEX_WIDTH(BANK_INDEX_WIDTH),
    .IDLE_CYCLES(IDLE_CYCLES),
    .WAKEUP_CYCLES(WAKEUP_CYCLES)
  ) u_bank_pm (
    .clk(clk),
    .rst_n(rst_n),
    .req_valid(req_valid && (rd_en || wr_en)),
    .req_bank(req_bank),
    .req_ready(req_ready),
    .bank_clk_en(bank_clk_en),
    .bank_sleep(bank_sleep),
    .retention_save(retention_save),
    .retention_restore(retention_restore)
  );

  genvar b;
  generate
    for (b = 0; b < NUM_BANKS; b = b + 1) begin : g_bank
      sram_icg u_bank_icg (
        .clk(clk),
        .enable(bank_clk_en[b]),
        .test_enable(1'b0),
        .gclk(bank_clk[b])
      );

      // The memory array is intentionally not reset: bank sleep preserves data.
      // Reset affects controller/output state, not SRAM contents.
      always_ff @(posedge bank_clk[b]) begin
        if (req_valid && req_ready && (req_bank == b)) begin
          if (wr_en)
            mem[b][req_row] <= wdata;
          if (rd_en)
            bank_rdata[b] <= mem[b][req_row];
        end
      end
    end
  endgenerate

  // Behavioral initialization for deterministic simulation only.
  initial begin
    for (init_bank = 0; init_bank < NUM_BANKS; init_bank = init_bank + 1)
      for (init_row = 0; init_row < BANK_DEPTH; init_row = init_row + 1)
        mem[init_bank][init_row] = '0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rvalid <= 1'b0;
      last_read_bank <= '0;
    end else begin
      rvalid <= 1'b0;
      if (req_valid && req_ready && rd_en && !wr_en) begin
        rvalid <= 1'b1;
        last_read_bank <= req_bank;
      end
    end
  end

  assign rdata = bank_rdata[last_read_bank];

  // One request port: issue either a read or a write per accepted cycle.
  // Read/write concurrency and same-cycle same-bank conflicts are deliberately
  // outside this banked low-power example's scope.
endmodule
