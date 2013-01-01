module pois9#(parameter DELAY=1)
(input CLK, RESET, VALID, input[27:0] RAND, output reg [3:0] RESULT);
`include "function.v"
  always @(posedge CLK)
    if(RESET || !VALID) RESULT <= #DELAY 4'd0;
    else
      if     (RAND <= 'd036328788) RESULT <= #DELAY 4'd0;
      else if(RAND <= 'd108986365) RESULT <= #DELAY 4'd1;
      else if(RAND <= 'd181643942) RESULT <= #DELAY 4'd2;
      else if(RAND <= 'd230082327) RESULT <= #DELAY 4'd3;
      else if(RAND <= 'd254301519) RESULT <= #DELAY 4'd4;
      else if(RAND <= 'd263989196) RESULT <= #DELAY 4'd5;
      else if(RAND <= 'd267218422) RESULT <= #DELAY 4'd6;
      else if(RAND <= 'd268141058) RESULT <= #DELAY 4'd7;
      else if(RAND <= 'd268371717) RESULT <= #DELAY 4'd8;
      else if(RAND <= 'd268422975) RESULT <= #DELAY 4'd9;
      else if(RAND <= 'd268433227) RESULT <= #DELAY 4'd10;
      else if(RAND <= 'd268435091) RESULT <= #DELAY 4'd11;
      else if(RAND <= 'd268435402) RESULT <= #DELAY 4'd12;
      else if(RAND <= 'd268435450) RESULT <= #DELAY 4'd13;
      else                         RESULT <= #DELAY 4'd14;
endmodule
