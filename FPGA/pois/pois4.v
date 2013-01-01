module pois4#(parameter DELAY=1)
(input CLK, RESET, VALID, input [27:0] RAND, output reg [4:0] RESULT);
`include "function.v"
  always @(posedge CLK)
    if(RESET || !VALID) RESULT <= #DELAY 4'd0;
    else
      if     (RAND <= 'd004916566) RESULT <= #DELAY 5'd0;
      else if(RAND <= 'd004916566) RESULT <= #DELAY 5'd1;
      else if(RAND <= 'd024582834) RESULT <= #DELAY 5'd2;
      else if(RAND <= 'd063915369) RESULT <= #DELAY 5'd3;
      else if(RAND <= 'd116358749) RESULT <= #DELAY 5'd4;
      else if(RAND <= 'd168802129) RESULT <= #DELAY 5'd5;
      else if(RAND <= 'd210756833) RESULT <= #DELAY 5'd6;
      else if(RAND <= 'd238726636) RESULT <= #DELAY 5'd7;
      else if(RAND <= 'd254709380) RESULT <= #DELAY 5'd8;
      else if(RAND <= 'd266252473) RESULT <= #DELAY 5'd9;
      else if(RAND <= 'd267673161) RESULT <= #DELAY 5'd10;
      else if(RAND <= 'd268189775) RESULT <= #DELAY 5'd11;
      else if(RAND <= 'd268361980) RESULT <= #DELAY 5'd12;
      else if(RAND <= 'd268414966) RESULT <= #DELAY 5'd13;
      else if(RAND <= 'd268430105) RESULT <= #DELAY 5'd14;
      else if(RAND <= 'd268435151) RESULT <= #DELAY 5'd15;
      else if(RAND <= 'd268435388) RESULT <= #DELAY 5'd16;
      else if(RAND <= 'd268435441) RESULT <= #DELAY 5'd18;
      else if(RAND <= 'd268435452) RESULT <= #DELAY 5'd19;
      else if(RAND <= 'd268435454) RESULT <= #DELAY 5'd20;
      else                         RESULT <= #DELAY 5'd21;
endmodule
