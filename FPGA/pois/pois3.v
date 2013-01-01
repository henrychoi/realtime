module pois3#(parameter DELAY=1)
(input CLK, RESET, VALID, input [27:0] RAND, output reg [4:0] RESULT);
`include "function.v"
  always @(posedge CLK)
    if(RESET || !VALID) RESULT <= #DELAY 4'd0;
    else
      if     (RAND <= 'd013364614) RESULT <= #DELAY 5'd0;
      else if(RAND <= 'd053458457) RESULT <= #DELAY 5'd1;
      else if(RAND <= 'd113599222) RESULT <= #DELAY 5'd2;
      else if(RAND <= 'd173739987) RESULT <= #DELAY 5'd3;
      else if(RAND <= 'd218845561) RESULT <= #DELAY 5'd4;
      else if(RAND <= 'd245908905) RESULT <= #DELAY 5'd5;
      else if(RAND <= 'd259440577) RESULT <= #DELAY 5'd6;
      else if(RAND <= 'd265239865) RESULT <= #DELAY 5'd7;
      else if(RAND <= 'd267414598) RESULT <= #DELAY 5'd8;
      else if(RAND <= 'd268139509) RESULT <= #DELAY 5'd9;
      else if(RAND <= 'd268356982) RESULT <= #DELAY 5'd10;
      else if(RAND <= 'd268416293) RESULT <= #DELAY 5'd11;
      else if(RAND <= 'd268431121) RESULT <= #DELAY 5'd12;
      else if(RAND <= 'd268434543) RESULT <= #DELAY 5'd13;
      else if(RAND <= 'd268435276) RESULT <= #DELAY 5'd14;
      else if(RAND <= 'd268435423) RESULT <= #DELAY 5'd15;
      else if(RAND <= 'd268435450) RESULT <= #DELAY 5'd16;
      else if(RAND <= 'd268435455) RESULT <= #DELAY 5'd17;
      else                         RESULT <= #DELAY 5'd18;
endmodule
