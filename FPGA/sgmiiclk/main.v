module main(input RESET, SYSCLK_P, SYSCLK_N, SGMIICLK_Q0_P, SGMIICLK_Q0_N
  , output[7:0] GPIO_LED);
`include "function.v"
  wire sysclk, sgmiiclk;
  localparam COUNTER_SIZE = 28;
  reg[COUNTER_SIZE-1:0] sysclk_r, sgmiiclk_r;
  
  IBUFGDS sysclk_buf(.I(SYSCLK_P), .IB(SYSCLK_N), .O(sysclk));
  IBUFDS_GTXE1 sgmiiclk_buf(.I(SGMIICLK_Q0_P), .IB(SGMIICLK_Q0_N)
    , .CEB(`FALSE), .O(sgmiiclk), .ODIV2());

`ifdef CHECK_OUT_MMCM
  MMCM_ADV#(.CLKFBOUT_MULT_F(1.0), .DIVCLK_DIVIDE(1), .CLKFBOUT_PHASE(0)
    , .CLKIN1_PERIOD(8.0), .CLKIN2_PERIOD(10)
    , .CLKOUT0_DIVIDE_F(1.0), .CLKOUT0_PHASE(0)
    , .CLKOUT1_DIVIDE(1), .CLKOUT1_PHASE(0)
    , .CLKOUT2_DIVIDE(1), .CLKOUT2_PHASE(0)
    , .CLKOUT3_DIVIDE(1), .CLKOUT3_PHASE(0)
    , .CLOCK_HOLD("TRUE"))
    mmcm_adv_i(.CLKIN1(sgmiiclk), .CLKIN2(`FALSE), .CLKINSEL(`TRUE)
      , .CLKFBIN(clkfb_w)
      , .CLKOUT0(clkout0_o), .CLKOUT0B()
      , .DADDR(7'd0), .DCLK(`FALSE), .DEN(`FALSE), .DI(16'd0), .DWE(`FALSE)
      , .LOCKED(locked_w), .PSCLK(1'b0), .PSEN(1'b0), .PSINCDEC(1'b0)
      , .PSDONE(), .PWRDWN(1'b0), .RST(RESET));
`endif
  assign GPIO_LED = {{5{1'b0}}
    , sgmiiclk_r[COUNTER_SIZE-1], sysclk_r[COUNTER_SIZE-1], RESET};

  always @(posedge sysclk)
    if(RESET) sysclk_r <= 0;
    else sysclk_r <= sysclk_r + 1'b1;
    
  always @(posedge sgmiiclk)
    if(RESET) sgmiiclk_r <= 0;
    else sgmiiclk_r <= sgmiiclk_r + 1'b1;

endmodule

