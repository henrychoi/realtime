module main #(parameter SIMULATION=0, DELAY=1)
(input CLK_P, CLK_N, RESET
, output[7:0] GPIO_LED);
`include "function.v"

  wire CLK; //Derive a single clock from diff clock
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  
  localparam FIFO_WIDTH = 8;
  reg [FIFO_WIDTH-1:0] din, rd_ctr;
  wire[FIFO_WIDTH-1:0] dout;
  wire empty, full;
  reg wren, rden;

  better_fifo#(.WIDTH(FIFO_WIDTH), .DELAY(DELAY))
    fwft(.RESET(RESET), .CLK(CLK)
    , .wren(wren), .din(din), .full(), .almost_full(full) 
    , .empty(empty), .rden(rden), .dout(dout));

  assign GPIO_LED = {7'h0, full};

  always @(posedge CLK)
    if(RESET) begin
      din <= #DELAY 0;
      wren <= #DELAY `FALSE;

      rd_ctr <= #DELAY 0;
      rden <= #DELAY `FALSE;
    end else begin
      if(!full) din <= #DELAY din + `TRUE;
      wren <= #DELAY !full;

      if(!empty) rd_ctr <= #DELAY rd_ctr + `TRUE;
      rden <= #DELAY !empty && rd_ctr[0];
    end
endmodule
