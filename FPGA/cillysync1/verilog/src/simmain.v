`timescale 1 ns / 1 ns
module simmain;
`include "function.v"
  wire[7:0] GPIO_LED;
  reg RESET, CLK;
  wire CLK_N;

  initial begin
     CLK <= `FALSE;
     RESET = `FALSE;
#4   RESET = `TRUE;
#396 RESET = `FALSE;
  end
  
  assign CLK_N = ~CLK;
  always #2 CLK <= ~CLK;  

  main#(.SIMULATION(1), .DELAY(2))
    main(.GPIO_LED(GPIO_LED), .RESET(RESET)
    , .PCIE_PERST_B_LS() //The host's master bus reset
    , .PCIE_REFCLK_N(CLK_N), .PCIE_REFCLK_P(CLK)
    , .PCIE_RX_N(), .PCIE_RX_P(), .PCIE_TX_N(), .PCIE_TX_P());
endmodule
