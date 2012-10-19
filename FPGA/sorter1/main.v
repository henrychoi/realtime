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

  localparam N_PATCH = 600000 // Total # of patches I expect
    , SYNC_WINDOW = 2**13//I can handle up to this may out-of-order patches
    , FP_SIZE = 20;
  reg [log2(N_PATCH)-1:0] random;
  wire[log2(N_PATCH)-1:0] patch_num;
  reg [FP_SIZE-1:0] ctr;
  wire[FP_SIZE-1:0] wtsum;
  wire app_rdy;
  reg[1:0] ready_r; //To cross the clock domain
  wire fifo_full, fifo_empty, patch_ack, fifo_wr;

  assign fifo_wr = pll_locked && ready_r[1];
  generate
    if(SIMULATION)
      aurora_fifo_bram
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random, ctr}), .wr_en(fifo_wr), .full(fifo_full)
           , .rd_en(patch_ack), .dout({patch_num, wtsum})
           , .empty(fifo_empty), .sbiterr(), .dbiterr());
    else
      aurora_fifo
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random, ctr}), .wr_en(fifo_wr), .full(fifo_full)
           , .rd_en(patch_ack), .dout({patch_num, wtsum})
           , .empty(fifo_empty), .sbiterr(), .dbiterr());
  endgenerate

  application#(.DELAY(DELAY), .SYNC_WINDOW(SYNC_WINDOW), .FP_SIZE(FP_SIZE)
    , .N_PATCH(N_PATCH))
    app(.CLK(clk_240), .RESET(RESET || !pll_locked)
      , .GPIO_LED(GPIO_LED), .ready(app_rdy), .patch_ack(patch_ack)
      , .patch_val(!fifo_empty), .patch_num(patch_num), .wtsum(wtsum));

  always @(posedge clk_200)//Pseudo random number for the patch_num_offset
    if(!pll_locked) begin
      ctr <= #DELAY 0;
      random <= #DELAY 0; //Seed value for LFSR
      ready_r <= #DELAY 2'b00;
    end else begin
      ready_r[1] <= #DELAY ready_r[0]; //To cross the clock domain
      ready_r[0] <= #DELAY app_rdy;

      if(ready_r[1] && !fifo_full) begin
        ctr <= #DELAY ctr + `TRUE;
        random <= #DELAY 
          {ctr[log2(N_PATCH)-1:log2(SYNC_WINDOW)]
           // 13 bit (for 8K SYNC_WINDOW) LFSR implementation
           , random[11:0], !(random[12] ^ random[11] ^ random[10] ^ random[7])};
      end else begin
        ctr <= #DELAY 0;
        random <= #DELAY 0;
      end
    end
endmodule
