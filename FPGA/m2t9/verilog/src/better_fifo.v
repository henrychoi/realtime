// From http://www.billauer.co.il/reg_fifo.html
module better_fifo#(parameter DELAY=1
, FIFO_CLASS="Unk", WR_WIDTH=1, RD_WIDTH=1)
(input RESET, CLK, rden, wren, input[WR_WIDTH-1:0] din
, output empty, valid, full, overflow
, output reg[RD_WIDTH-1:0] dout);
`include "function.v"
  reg [RD_WIDTH-1:0] middle_dout;
  wire[RD_WIDTH-1:0] fifo_dout;
  reg fifo_valid, middle_valid, dout_valid;
  wire fifo_empty, fifo_rden, will_update_middle, will_update_dout;

  generate
    if(FIFO_CLASS == "xb2dram")
      xb2dram fifo(.clk(CLK), .rst(RESET)
        , .din(din), .wr_en(wren)
        , .full(), .almost_full(full), .overflow(overflow)
        , .rd_en(fifo_rden), .dout(fifo_dout), .empty(fifo_empty)
        , .sbiterr(), .dbiterr());
    else if(FIFO_CLASS == "xb2pixel")
      xb2pixel fifo(.clk(CLK), .rst(RESET)
        , .din(din), .wr_en(wren)
        , .full(), .almost_full(full)//, .prog_full()
        , .rd_en(fifo_rden), .dout(fifo_dout), .empty(fifo_empty)
        , .sbiterr(), .dbiterr());
  endgenerate

  assign will_update_middle = fifo_valid && (middle_valid == will_update_dout);
  assign will_update_dout = (middle_valid || fifo_valid)
                          && (rden || !dout_valid);
  assign fifo_rden = !fifo_empty
    && !(middle_valid && dout_valid && fifo_valid);
  assign empty = !dout_valid;

  always @(posedge CLK)
    if(RESET) begin
      fifo_valid <= #DELAY `FALSE;
      middle_valid <= #DELAY `FALSE;
      dout_valid <= #DELAY `FALSE;
      dout <= #DELAY 0;
      middle_dout <= #DELAY 0;
    end else begin
      if(will_update_middle) middle_dout <= #DELAY fifo_dout;
      if(will_update_dout) dout <= #DELAY
        middle_valid ? middle_dout : fifo_dout;
      
      if(fifo_rden) fifo_valid <= #DELAY `TRUE;
      else if (will_update_middle || will_update_dout)
         fifo_valid <= #DELAY `FALSE;
      
      if(will_update_middle) middle_valid <= #DELAY `TRUE;
      else if (will_update_dout) middle_valid <= #DELAY `FALSE;
      
      if (will_update_dout) dout_valid <= #DELAY `TRUE;
      else if (rden) dout_valid <= #DELAY `FALSE;
   end 
endmodule
