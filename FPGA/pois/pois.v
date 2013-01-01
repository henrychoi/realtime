module pois#(parameter DELAY=1)
(input CLK, RESET, VALID, input[31:0] LAMBDA, RAND
, output reg[9:0] RESULT);
`include "function.v"
  wire comp_rdy
     , isLessThan1p5, isLessThan2p5, isLessThan3p5, isLessThan4p5
     , isLessThan5p5, isLessThan6p5;
  wire[3:0] pois1_rand, pois2_rand;
  wire[4:0] pois3_rand, pois4_rand, pois5_rand, pois6_rand;
  wire[9:0] pois_rand;

  fless lessThan1p5(.a(LAMBDA), .b('h3fc00000), .operation_nd(VALID)
                  , .clk(CLK), .result(isLessThan1p5), .rdy());
  fless lessThan2p5(.a(LAMBDA), .b('h40200000), .operation_nd(VALID)
                  , .clk(CLK), .result(isLessThan2p5), .rdy(comp_rdy));
  fless lessThan3p5(.a(LAMBDA), .b('h40600000), .operation_nd(VALID)
                  , .clk(CLK), .result(isLessThan3p5), .rdy());
  fless lessThan4p5(.a(LAMBDA), .b('h40900000), .operation_nd(VALID)
                  , .clk(CLK), .result(isLessThan4p5), .rdy());
  fless lessThan5p5(.a(LAMBDA), .b('h40b00000), .operation_nd(VALID)
                  , .clk(CLK), .result(isLessThan5p5), .rdy());
  fless lessThan6p5(.a(LAMBDA), .b('h40d00000), .operation_nd(VALID)
                  , .clk(CLK), .result(isLessThan6p5), .rdy());

  pois1#(.DELAY(DELAY)) pois1(.CLK(CLK), .RESET(RESET), .VALID(VALID)
    , .RAND(RAND[0+:28]) , .RESULT(pois1_rand));
  pois2#(.DELAY(DELAY)) pois2(.CLK(CLK), .RESET(RESET), .VALID(VALID)
    , .RAND(RAND[0+:28]) , .RESULT(pois2_rand));
  pois3#(.DELAY(DELAY)) pois3(.CLK(CLK), .RESET(RESET), .VALID(VALID)
    , .RAND(RAND[0+:28]) , .RESULT(pois3_rand));
  pois4#(.DELAY(DELAY)) pois4(.CLK(CLK), .RESET(RESET), .VALID(VALID)
    , .RAND(RAND[0+:28]) , .RESULT(pois4_rand));
  pois5#(.DELAY(DELAY)) pois5(.CLK(CLK), .RESET(RESET), .VALID(VALID)
    , .RAND(RAND[0+:28]) , .RESULT(pois5_rand));
  pois6#(.DELAY(DELAY)) pois6(.CLK(CLK), .RESET(RESET), .VALID(VALID)
    , .RAND(RAND[0+:28]) , .RESULT(pois6_rand));

  assign #DELAY pois_rand = 0;

  always @(posedge CLK)
    if(RESET || !comp_rdy) begin
      RESULT <= #DELAY 0;
    end else
      if(isLessThan1p5) RESULT <= #DELAY {6'h00, pois1_rand};
      else if(isLessThan2p5) RESULT <= #DELAY {6'h00, pois2_rand};
      else if(isLessThan3p5) RESULT <= #DELAY {5'h00, pois3_rand};
      else if(isLessThan4p5) RESULT <= #DELAY {5'h00, pois4_rand};
      else if(isLessThan5p5) RESULT <= #DELAY {5'h00, pois5_rand};
      else if(isLessThan6p5) RESULT <= #DELAY {5'h00, pois6_rand};
      else RESULT <= #DELAY pois_rand;
endmodule
