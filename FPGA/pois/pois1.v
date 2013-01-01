module pois1#(parameter DELAY=1)
(input CLK, RESET, VALID, input [27:0] RAND, output reg [3:0] RESULT);
`include "function.v"
  always @(posedge CLK)
    if(RESET || !VALID) RESULT <= #DELAY 4'd0;
    else
      if     (RAND <= 'd098751885) RESULT <= #DELAY 4'd0;
      else if(RAND <= 'd197503771) RESULT <= #DELAY 4'd1;
      else if(RAND <= 'd246879714) RESULT <= #DELAY 4'd2;
      else if(RAND <= 'd263338362) RESULT <= #DELAY 4'd3;
      else if(RAND <= 'd267453024) RESULT <= #DELAY 4'd4;
      else if(RAND <= 'd268275956) RESULT <= #DELAY 4'd5;
      else if(RAND <= 'd268413111) RESULT <= #DELAY 4'd6;
      else if(RAND <= 'd268432705) RESULT <= #DELAY 4'd7;
      else if(RAND <= 'd268435154) RESULT <= #DELAY 4'd8;
      else if(RAND <= 'd268435426) RESULT <= #DELAY 4'd9;
      else if(RAND <= 'd268435453) RESULT <= #DELAY 4'd10;
      else if(RAND <= 'd268435455) RESULT <= #DELAY 4'd11;
      else                         RESULT <= #DELAY 4'd12;
endmodule
