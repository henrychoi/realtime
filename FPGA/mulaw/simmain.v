`timescale 100 ps / 100 ps
module simmain;
`include "function.v"
  reg RESET, CLK;
  wire CLK_N;

  initial begin
    CLK <= `FALSE;
    RESET = `FALSE;
#25 RESET = `TRUE;
#975 RESET = `FALSE;
  end
  
  assign CLK_N = ~CLK;
  always #25 CLK <= ~CLK;  

  main#(.SIMULATION(1), .DELAY(2))
    main(.RESET(RESET), .CLK_P(CLK), .CLK_N(CLK_N));
endmodule
