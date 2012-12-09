module application#(parameter DELAY=1)
( input CLK, RESET, output[7:0] GPIO_LED);
`include "function.v"  
  reg [31:0] frand;
  wire[31:0] rand;
  wire valid, error;

  tausworth#(.DELAY(1)) tausworth(.CLK(CLK), .RESET(RESET)
    , .valid(valid), .error(error), .rand(rand));

  assign #DELAY GPIO_LED = {error, valid, frand[31:26]};
  always @(posedge CLK)
    frand <= #DELAY {`FALSE//sign
                    , `FALSE, rand[24+:6], `FALSE //exponent
                    , rand[0+:23]};//fraction
endmodule
