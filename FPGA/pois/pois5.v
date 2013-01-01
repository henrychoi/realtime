module pois5#(parameter DELAY=1)
(input CLK, RESET, VALID, input [27:0] RAND, output reg [4:0] RESULT);
`include "function.v"
  always @(posedge CLK)
    if(RESET || !VALID) RESULT <= #DELAY 4'd0;
    else
      if     (RAND <= 'd001808703) RESULT <= #DELAY 5'd0;
      else if(RAND <= 'd010852222) RESULT <= #DELAY 5'd1;
      else if(RAND <= 'd033461020) RESULT <= #DELAY 5'd2;
      else if(RAND <= 'd071142351) RESULT <= #DELAY 5'd3;
      else if(RAND <= 'd118244014) RESULT <= #DELAY 5'd4;
      else if(RAND <= 'd165345677) RESULT <= #DELAY 5'd5;
      else if(RAND <= 'd204597063) RESULT <= #DELAY 5'd6;
      else if(RAND <= 'd232633767) RESULT <= #DELAY 5'd7;
      else if(RAND <= 'd250156707) RESULT <= #DELAY 5'd8;
      else if(RAND <= 'd259891674) RESULT <= #DELAY 5'd9;
      else if(RAND <= 'd264759157) RESULT <= #DELAY 5'd10;
      else if(RAND <= 'd266971649) RESULT <= #DELAY 5'd11;
      else if(RAND <= 'd267893521) RESULT <= #DELAY 5'd12;
      else if(RAND <= 'd268248087) RESULT <= #DELAY 5'd13;
      else if(RAND <= 'd268374718) RESULT <= #DELAY 5'd14;
      else if(RAND <= 'd268416928) RESULT <= #DELAY 5'd15;
      else if(RAND <= 'd268430119) RESULT <= #DELAY 5'd16;
      else if(RAND <= 'd268433999) RESULT <= #DELAY 5'd17;
      else if(RAND <= 'd268435077) RESULT <= #DELAY 5'd18;
      else if(RAND <= 'd268435361) RESULT <= #DELAY 5'd19;
      else if(RAND <= 'd268435432) RESULT <= #DELAY 5'd20;
      else if(RAND <= 'd268435449) RESULT <= #DELAY 5'd21;
      else if(RAND <= 'd268435453) RESULT <= #DELAY 5'd22;
      else if(RAND <= 'd268435454) RESULT <= #DELAY 5'd23;
      else                         RESULT <= #DELAY 5'd24;
endmodule
