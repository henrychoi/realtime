`timescale 1ns/1ns

module simmain;
`include "function.v"
  wire[7:0] GPIO_LED;
  wire clk_ref_p, clk_ref_n;
  reg sys_rst, clk_ref;
  
  initial begin
    clk_ref = `TRUE;
    sys_rst = `FALSE;

#12 sys_rst = `TRUE;
#5  sys_rst = `FALSE;
  end

  localparam REFCLK_PERIOD=5;
  always clk_ref = #REFCLK_PERIOD ~clk_ref;

  assign clk_ref_p = clk_ref;
  assign clk_ref_n = ~clk_ref;


  //**************************************************************************//

  main #(.SIMULATION(1))
  main(.GPIO_LED(GPIO_LED), .clk_ref_p(clk_ref_p), .clk_ref_n(clk_ref_n)
       , .sys_rst(sys_rst));
endmodule

