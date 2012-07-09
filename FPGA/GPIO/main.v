module main#(TIMER_SIZE = 27)
(input CLK_P, input CLK_N, input reset
    , input [4:0] button5, input [7:0] switch8
    , output [4:0] led5, output [7:0] led8);
  reg[TIMER_SIZE-1:0] timer;
  wire clk;
  
  assign led5 = {button5[4:1], timer[TIMER_SIZE-1]};
  assign led8= {switch8[7:1], timer[0]};

  IBUFGDS dsClkBuf(.O(clk), .I(CLK_P), .IB(CLK_N));

  always @(posedge reset, posedge clk) begin
    if(reset) timer <= 0;
    else timer <= timer + 1'b1;
  end//always
endmodule
