module sram_banked_ctrl_lp_tb;
  localparam integer BANK_INDEX_WIDTH = 2;
  localparam integer ROW_WIDTH = 4;

  logic clk = 1'b0;
  logic rst_n;
  logic req_valid;
  logic [BANK_INDEX_WIDTH-1:0] req_bank;
  logic [ROW_WIDTH-1:0] req_row;
  logic rd_en, wr_en;
  logic [31:0] wdata;
  wire [31:0] rdata;
  logic rvalid, req_ready;
  logic [3:0] bank_sleep, bank_clk_en, retention_save, retention_restore;
  integer save_events, restore_events;
  logic [31:0] read_value;

  always #5 clk = ~clk;
  always @(posedge clk) begin
    for (integer bank = 0; bank < 4; bank = bank + 1) begin
      if (retention_save[bank]) save_events = save_events + 1;
      if (retention_restore[bank]) restore_events = restore_events + 1;
    end
  end

  sram_banked_ctrl_lp #(
    .DATA_WIDTH(32), .ADDR_WIDTH(6), .NUM_BANKS(4),
    .IDLE_CYCLES(4), .WAKEUP_CYCLES(2)
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .req_valid(req_valid), .req_bank(req_bank), .req_row(req_row),
    .rd_en(rd_en), .wr_en(wr_en), .wdata(wdata),
    .rdata(rdata), .rvalid(rvalid), .req_ready(req_ready),
    .bank_sleep(bank_sleep), .bank_clk_en(bank_clk_en),
    .retention_save(retention_save), .retention_restore(retention_restore)
  );

  task automatic write_word(
    input logic [BANK_INDEX_WIDTH-1:0] bank,
    input logic [ROW_WIDTH-1:0] row,
    input logic [31:0] value
  );
    begin
      @(negedge clk);
      req_valid = 1'b1;
      req_bank = bank;
      req_row = row;
      rd_en = 1'b0;
      wr_en = 1'b1;
      wdata = value;
      wait (req_ready === 1'b1);
      @(posedge clk);
      #1;
      @(negedge clk);
      req_valid = 1'b0;
      wr_en = 1'b0;
    end
  endtask

  task automatic read_word(
    input logic [BANK_INDEX_WIDTH-1:0] bank,
    input logic [ROW_WIDTH-1:0] row,
    output logic [31:0] value
  );
    begin
      @(negedge clk);
      req_valid = 1'b1;
      req_bank = bank;
      req_row = row;
      rd_en = 1'b1;
      wr_en = 1'b0;
      wait (req_ready === 1'b1);
      @(posedge clk);
      #1;
      if (!rvalid)
        $fatal(1, "Read response valid did not assert");
      value = rdata;
      @(negedge clk);
      req_valid = 1'b0;
      rd_en = 1'b0;
    end
  endtask

  initial begin
    save_events = 0;
    restore_events = 0;
    rst_n = 1'b0;
    req_valid = 1'b0;
    req_bank = '0;
    req_row = '0;
    rd_en = 1'b0;
    wr_en = 1'b0;
    wdata = '0;

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    // All four idle banks should independently enter retention sleep.
    wait (&bank_sleep);
    // The monitor samples registered pulse outputs on the following clock.
    @(posedge clk);
    #1;
    if (bank_clk_en != 4'b0000)
      $fatal(1, "Bank clocks must be gated in sleep");
    if (save_events < 4)
      $fatal(1, "Expected a retention-save request for every bank");

    // Wake bank 2, write a word, then allow it to sleep again.
    write_word(2'd2, 4'd3, 32'hA5A5_1234);
    if (bank_sleep[1] !== 1'b1)
      $fatal(1, "Access to bank 2 must not wake bank 1");
    wait (bank_sleep[2]);

    // Bank 2 data must survive its sleep interval.
    read_word(2'd2, 4'd3, read_value);
    if (read_value !== 32'hA5A5_1234)
      $fatal(1, "Bank 2 retention/readback mismatch: %08h", read_value);

    // Same row in another bank must remain independent.
    write_word(2'd1, 4'd3, 32'h5A5A_BEEF);
    #1;
    if (dut.mem[1][3] !== 32'h5A5A_BEEF)
      $fatal(1, "Bank 1 write was not stored: mem=%08h state=%0d req_ready=%b bank_clk_en=%b",
             dut.mem[1][3], dut.u_bank_pm.bank_state[1], req_ready, bank_clk_en[1]);
    read_word(2'd1, 4'd3, read_value);
    if (read_value !== 32'h5A5A_BEEF)
      $fatal(1, "Bank 1 readback mismatch: %08h mem=%08h", read_value, dut.mem[1][3]);

    wait (&bank_sleep);
    if (restore_events < 2)
      $fatal(1, "Expected restore requests when sleeping banks wake");

    $display("PASS: bank-level idle gating, retention handshakes, wake-up, and data preservation.");
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "Timeout in sram_banked_ctrl_lp_tb");
  end
endmodule
