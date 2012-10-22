module main#(parameter SIMULATION=0, DELAY=1)
(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
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
    , FP_SIZE = 20
    , N_CAM = 3;
  reg [log2(SYNC_WINDOW)-2:0] ctr[N_CAM-1:0], random[N_CAM-1:0];
  reg [log2(N_PATCH)-1:0] random_offset;
  wire[log2(N_PATCH)-1:0] random_patch_num[N_CAM-1:0], patch_num[N_CAM-1:0];
  wire[FP_SIZE-1:0] wtsum[N_CAM-1:0];
  wire app_rdy;
  reg[1:0] ready_r; //To cross the clock domain
  wire[N_CAM-1:0] fifo_full, fifo_empty, patch_val, patch_ack, fifo_wr;

  genvar geni;
  generate
    for(geni=0; geni < N_CAM; geni=geni+1) begin
      if(SIMULATION) aurora_fifo_bram
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random_patch_num[geni]
                 , {(FP_SIZE-log2(SYNC_WINDOW)+1){`FALSE}}, ctr})
           , .wr_en(fifo_wr[geni]), .full(fifo_full[geni])
           , .rd_en(patch_ack[geni]), .dout({patch_num[geni], wtsum[geni]})
           , .empty(fifo_empty[geni]), .sbiterr(), .dbiterr());
      else aurora_fifo
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random_patch_num[geni]
                 , {(FP_SIZE-log2(SYNC_WINDOW)+1){`FALSE}}, ctr})
           , .wr_en(fifo_wr[geni]), .full(fifo_full[geni])
           , .rd_en(patch_ack[geni]), .dout({patch_num[geni], wtsum[geni]})
           , .empty(fifo_empty[geni]), .sbiterr(), .dbiterr());

      assign random_patch_num[geni] = random[geni] + random_offset;
      assign fifo_wr[geni] = pll_locked && ready_r[1]
                           && (random_patch_num[geni] < N_PATCH
                               || &random_patch_num[geni]);
      assign patch_val[geni] = ~fifo_empty[geni];
    end
  endgenerate

  application#(.DELAY(DELAY), .SYNC_WINDOW(SYNC_WINDOW), .FP_SIZE(FP_SIZE)
    , .N_PATCH(N_PATCH), .N_CAM(N_CAM))
    app(.CLK(clk_240), .RESET(RESET || !pll_locked)
      , .GPIO_LED(GPIO_LED), .ready(app_rdy), .patch_ack(patch_ack)
      , .patch_val(patch_val), .patch_num0(patch_num[0])
      , .patch_num1(patch_num[1]), .patch_num2(patch_num[2])
      , .wtsum0(wtsum[0]), .wtsum1(wtsum[1]), .wtsum2(wtsum[2]));

  localparam INIT = 0, INTERFRAME = 1, INTER2INTRA = 2, INTRAFRAME = 3
    , ERROR = 4, N_STATE = 5;
  reg [log2(N_STATE)-1:0] state;
  
  integer i;
  always @(posedge clk_200)//Pseudo random number for the patch_num_offset
    if(!pll_locked) begin
      ctr <= #DELAY 0;
      ready_r <= #DELAY 2'b00;
      for(i=0; i < N_CAM; i=i+1) begin
        random <= #DELAY i; //Seed value for LFSR
        random_offset <= #DELAY 0;
      end
      state <= #DELAY INIT;
    end else begin
      ready_r[1] <= #DELAY ready_r[0]; //To cross the clock domain
      ready_r[0] <= #DELAY app_rdy;

      case(state)
        INIT: if(ready_r[1]) state <= #DELAY INTERFRAME;

        INTERFRAME: begin
          for(i=0; i < N_CAM; i=i+1) begin
            random <= #DELAY 0;
            random_offset <= #DELAY -1;//Reserved patch num
          end
          ctr <= #DELAY 1;//SOF
          state <= #DELAY INTER2INTRA;
        end
        
        INTER2INTRA: begin
          for(i=0; i < N_CAM; i=i+1) begin
            random <= #DELAY i;
            random_offset <= #DELAY 0;
          end
          ctr <= #DELAY 0;
          state <= #DELAY INTRAFRAME;
        end

        INTRAFRAME:
          if(!ready_r[1] || fifo_full) begin
            for(i=0; i < N_CAM; i=i+1) begin
              random <= #DELAY i;
              random_offset <= #DELAY 0;
            end
            ctr <= #DELAY 0;
            state <= #DELAY ERROR;
          end else begin
            ctr <= #DELAY ctr + `TRUE;
            for(i=0; i < N_CAM; i=i+1) begin
              //12 bit implementation
              random <= #DELAY {random[10:0]
                , !(random[11] ^ random[10] ^ random[9] ^ random[3])};
              //$display("%d ctr: %d, random: %d", $time, ctr, random);
            end
            
            if(ctr == (2**12-2)) begin //The last random number
              ctr <= #DELAY 0;
              
              if(random_offset > (N_PATCH - 2**12)) begin
                //Completely done with N_PATCH
                for(i=0; i < N_CAM; i=i+1)
                  random_offset <= #DELAY -1;//Reserved patch num
                state <= #DELAY INTERFRAME;
              end else begin
                for(i=0; i < N_CAM; i=i+1)
                  random_offset <= #DELAY random_offset + (2**12-1);
                state <= #DELAY INTRAFRAME;
              end
            end
          end

        default: begin
          for(i=0; i < N_CAM; i=i+1) begin
            random <= #DELAY i;
            random_offset <= #DELAY 0;
          end
          ctr <= #DELAY 0;
          state <= #DELAY ERROR;
        end
      endcase
    end
endmodule
