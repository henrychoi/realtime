module main#(SIMULATION=0)
(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
  localparam DELAY = 3;
  wire CLK, clk_200, clk_240, clk_fbk, pll_locked;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  MMCM_ADV#(.CLKFBOUT_MULT_F(6.0), .DIVCLK_DIVIDE(1), .CLKIN1_PERIOD(5)
    , .CLKOUT0_DIVIDE_F(6.0) //for 200 MHz clock
    , .CLKOUT1_DIVIDE(5)) //for 240 MHz clock
    mmcm(.RST(RESET), .CLKIN1(CLK), .CLKIN2(`FALSE), .CLKINSEL(`TRUE)
       , .CLKFBIN(clk_fbk), .CLKFBOUT(clk_fbk) //Must be the same clk
       , .CLKOUT0(clk_200), .CLKOUT1(clk_240)
       , .DO(), .DRDY(), .DADDR(7'd0), .DCLK(`FALSE), .DEN(`FALSE), .DI(16'd0)
       , .DWE(`FALSE)
       , .LOCKED(pll_locked)
       , .PSCLK(`FALSE), .PSEN(`FALSE), .PSINCDEC(`FALSE), .PWRDWN(`FALSE));

  localparam N_PATCH = 600000, FP_SIZE = 20;
  reg [log2(N_PATCH)-1:0] random;
  wire[log2(N_PATCH)-1:0] patch_num;
  wire[FP_SIZE-1:0] wtsum;
  wire app_rdy;
  reg[1:0] ready_r; //To cross the clock domain
  wire fifo_full, fifo_empty, patch_ack, fifo_wr;

  assign fifo_wr = pll_locked && ready_r[1];
  generate
    if(SIMULATION)
      aurora_fifo_bram
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random, random}), .wr_en(fifo_wr), .full(fifo_full)
           , .rd_en(patch_ack), .dout({patch_num, wtsum}), .empty(fifo_empty)
           , .valid(fifo_valid), .sbiterr(), .dbiterr());
    else
      aurora_fifo
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random, random}), .wr_en(fifo_wr), .full(fifo_full)
           , .rd_en(patch_ack), .dout({patch_num, wtsum}), .empty(fifo_empty)
           , .sbiterr(), .dbiterr());
  endgenerate

  application#(.DELAY(DELAY), .N_PATCH(N_PATCH), .FP_SIZE(FP_SIZE))
    app(.CLK(clk_240), .RESET(RESET || !pll_locked)
      , .GPIO_LED(GPIO_LED), .ready(app_rdy), .patch_ack(patch_ack)
      , .patch_val(!fifo_empty), .patch_num(patch_num), .wtsum(wtsum));

  always @(posedge clk_200)// generate pseudo random number for the random
    if(!pll_locked) begin
      random <= #DELAY 0; //Seed value for LFSR
      ready_r <= #DELAY 2'b00;
    end else begin
      ready_r[1] <= #DELAY ready_r[0]; //To cross the clock domain
      ready_r[0] <= #DELAY app_rdy;
      
      random <= #DELAY ready_r[1] ? {random[8:0], !(random[9]^random[6])} : 0;
    end    
endmodule
