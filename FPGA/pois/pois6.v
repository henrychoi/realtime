module pois6#(parameter DELAY=1)
(input CLK, RESET, VALID, input [27:0] RAND, output reg [4:0] RESULT);
`include "function.v"
  always @(posedge CLK)
    if(RESET || !VALID) RESULT <= #DELAY 4'd0;
    else
      if     (RAND <= 'd000665384) RESULT <= #DELAY 5'd0;
      else if(RAND <= 'd004657694) RESULT <= #DELAY 5'd1;
      else if(RAND <= 'd016634623) RESULT <= #DELAY 5'd2;
      else if(RAND <= 'd040588482) RESULT <= #DELAY 5'd3;
      else if(RAND <= 'd076519270) RESULT <= #DELAY 5'd4;
      else if(RAND <= 'd119636216) RESULT <= #DELAY 5'd5;
      else if(RAND <= 'd162753162) RESULT <= #DELAY 5'd6;
      else if(RAND <= 'd199710544) RESULT <= #DELAY 5'd7;
      else if(RAND <= 'd227428581) RESULT <= #DELAY 5'd8;
      else if(RAND <= 'd245907272) RESULT <= #DELAY 5'd9;
      else if(RAND <= 'd256994487) RESULT <= #DELAY 5'd10;
      else if(RAND <= 'd263042059) RESULT <= #DELAY 5'd11;
      else if(RAND <= 'd266065845) RESULT <= #DELAY 5'd12;
      else if(RAND <= 'd267461438) RESULT <= #DELAY 5'd13;
      else if(RAND <= 'd268059549) RESULT <= #DELAY 5'd14;
      else if(RAND <= 'd268298794) RESULT <= #DELAY 5'd15;
      else if(RAND <= 'd268388511) RESULT <= #DELAY 5'd16;
      else if(RAND <= 'd268420176) RESULT <= #DELAY 5'd17;
      else if(RAND <= 'd268430731) RESULT <= #DELAY 5'd18;
      else if(RAND <= 'd268434064) RESULT <= #DELAY 5'd19;
      else if(RAND <= 'd268435064) RESULT <= #DELAY 5'd20;
      else if(RAND <= 'd268435350) RESULT <= #DELAY 5'd21;
      else if(RAND <= 'd268435428) RESULT <= #DELAY 5'd22;
      else if(RAND <= 'd268435448) RESULT <= #DELAY 5'd23;
      else if(RAND <= 'd268435453) RESULT <= #DELAY 5'd24;
      else if(RAND <= 'd268435454) RESULT <= #DELAY 5'd25;
      else                         RESULT <= #DELAY 5'd26;
endmodule
