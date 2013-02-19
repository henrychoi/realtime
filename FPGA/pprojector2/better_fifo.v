// From http://www.billauer.co.il/reg_fifo.html
// When using this, do NOT use embedded registers in BRAM or FIFO, because
// that will add another read latency cycle, and invalidate the logic below
module better_fifo#(parameter TYPE="XILLYBUS", WIDTH=1, DELAY=1)
(input RESET, RD_CLK, WR_CLK, rden, wren, input[WIDTH-1:0] din
, output empty, almost_empty, high, full, almost_full
, output reg[WIDTH-1:0] dout);
`include "function.v"
  reg [WIDTH-1:0] middle_dout;
  wire[WIDTH-1:0] fifo_dout;
  reg fifo_valid, middle_valid, dout_valid;
  wire fifo_empty, fifo_rden, will_update_middle, will_update_dout;

  generate
    if(TYPE == "XILLYBUS")
      standard32x512_bram_fifo fifo(.rd_clk(RD_CLK), .wr_clk(WR_CLK), .rst(RESET)
      , .din(din), .wr_en(wren), .full(full), .almost_full(almost_full)
      , .rd_en(fifo_rden), .dout(fifo_dout), .empty(fifo_empty));
    else if(TYPE == "ToRAM" || TYPE == "FromRAM")
      standard256_fifo fifo(.clk(RD_CLK), .rst(RESET)
      , .din(din), .wr_en(wren)
      , .full(full), .almost_full(almost_full), .prog_full(high)
      , .rd_en(fifo_rden), .dout(fifo_dout), .empty(fifo_empty)
      , .almost_empty(fifo_almost_empty));
    else if(TYPE == "Pulse")
      standard_pulse_fifo fifo(.clk(RD_CLK), .rst(RESET)
      , .din(din), .wr_en(wren)
      , .full(full), .almost_full(almost_full), .prog_full(high)
      , .rd_en(fifo_rden), .dout(fifo_dout), .empty(fifo_empty));
  endgenerate
  
  assign #DELAY will_update_middle = fifo_valid
                                   && (middle_valid == will_update_dout);
  assign #DELAY will_update_dout = (middle_valid || fifo_valid)
                                 && (rden || !dout_valid);
  assign #DELAY fifo_rden = !fifo_empty
                          && !(middle_valid && dout_valid && fifo_valid);
  assign #DELAY empty = !dout_valid;

  always @(posedge RD_CLK)
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
