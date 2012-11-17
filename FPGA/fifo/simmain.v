`timescale 1 ns / 1 ns

module simmain;
`include "function.v"

  wire[7:0] GPIO_LED;
  reg RESET, CLK;

  initial begin
#0  CLK <= `FALSE;
    RESET <= `FALSE;
#4  RESET <= `TRUE;
#8  RESET <= `FALSE;
  end

  always #2 CLK = ~CLK;

  main#(.SIMULATION(1), .DELAY(2))
    main(.RESET(RESET), .CLK_P(CLK), .CLK_N(~CLK), .GPIO_LED(GPIO_LED));
endmodule
