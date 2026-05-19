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
