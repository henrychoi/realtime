`timescale 10ns / 1ns
module main#(TIMER_SIZE = 25)
(input clk, input reset, input [4:0] button5, input [7:0] switch8
    , output [4:0] led5, output [7:0] led8);
  reg[TIMER_SIZE-1:0] timer;
  
  assign led5 = {timer[TIMER_SIZE-1]
    , button5[1], button5[2], button5[3], button5[4]};
  assign led8 = {clk, switch8[1], switch8[2], switch8[3]
    , switch8[4], switch8[5], switch8[6], switch8[7]};

  /*  
  IBUFGDS my_clk_inst (.O  (clk200),
                    .I  (clk200_P),
                    .IB (clk200_N));
  */
  always @(posedge reset, posedge clk) begin
    if(reset) timer <= 0;
    else timer <= timer + 1'b1;
  end//always
endmodule
