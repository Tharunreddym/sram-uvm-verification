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
