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
    , LFSR_SIZE = log2(SYNC_WINDOW) - 1
    , FP_SIZE = 20
    , N_CAM = 3;
  reg [log2(SYNC_WINDOW)-2:0] ctr[N_CAM-1:0], random[N_CAM-1:0];
  reg [log2(N_PATCH)-1:0] random_offset;
  wire[log2(N_PATCH)-1:0] random_patch_num[N_CAM-1:0];
  wire[log2(N_PATCH)+FP_SIZE-1:0] aurora_data[N_CAM-1:0];
  wire app_rdy;
  reg[1:0] ready_r; //To cross the clock domain
  wire[N_CAM-1:0] fifo_full, fifo_empty, input_val, input_ack, fifo_wr;

  genvar geni;
  generate
    for(geni=0; geni < N_CAM; geni=geni+1) begin
      if(SIMULATION) aurora_fifo_bram
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random_patch_num[geni]
                 , {(FP_SIZE-log2(SYNC_WINDOW)+1){`FALSE}}, ctr[geni]})
           , .wr_en(fifo_wr[geni]), .full(fifo_full[geni])
           , .rd_en(input_ack[geni]), .dout(aurora_data[geni])
           , .empty(fifo_empty[geni]), .sbiterr(), .dbiterr());
      else aurora_fifo
        fifo(.rst(!pll_locked), .wr_clk(clk_200), .rd_clk(clk_240)
           , .din({random_patch_num[geni]
                 , {(FP_SIZE-log2(SYNC_WINDOW)+1){`FALSE}}, ctr[geni]})
           , .wr_en(fifo_wr[geni]), .full(fifo_full[geni])
           , .rd_en(input_ack[geni]), .dout(aurora_data[geni])
           , .empty(fifo_empty[geni]), .sbiterr(), .dbiterr());

      assign random_patch_num[geni] = random[geni] + random_offset;
      assign fifo_wr[geni] =
        (state == INTERFRAME || state == INTER2INTRA || state == INTRAFRAME)
        && (random_patch_num[geni] < N_PATCH
            || &random_patch_num[geni][1+:(log2(N_PATCH)-1)]);
      assign input_val[geni] = ~fifo_empty[geni];
    end
  endgenerate

  application#(.DELAY(DELAY), .SYNC_WINDOW(SYNC_WINDOW), .FP_SIZE(FP_SIZE)
    , .N_PATCH(N_PATCH), .N_CAM(N_CAM))
    app(.CLK(clk_240), .RESET(RESET || !pll_locked)
      , .GPIO_LED(GPIO_LED), .ready(app_rdy), .input_ack(input_ack)
      , .input_val(input_val)
      , .aurora_data0(aurora_data[0])
      , .aurora_data1(aurora_data[1])
      , .aurora_data2(aurora_data[2]));

  localparam ERROR = 0, INIT = 1
    , INTERFRAME = 2, INTER2INTRA = 3, INTRAFRAME = 4, N_STATE = 5;
  reg [log2(N_STATE)-1:0] state;
  
  integer i;
  always @(posedge clk_200)//Pseudo random number for the patch_num_offset
    if(!pll_locked) begin
      ready_r <= #DELAY 2'b00;
      random[0] <= #DELAY 512;
      random[1] <= #DELAY 1024;
      random[2] <= #DELAY 2048;
      random_offset <= #DELAY 0;
      for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
      state <= #DELAY INIT;
    end else begin
      ready_r[1] <= #DELAY ready_r[0]; //To cross the clock domain
      ready_r[0] <= #DELAY app_rdy;

      case(state)
        INIT:
          if(ready_r[1]) begin
            for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
            state <= #DELAY INTERFRAME;
          end

        INTERFRAME: begin
          for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY ctr[i] + `TRUE;
          if(ctr[0] == 'h003) begin
            random_offset <= #DELAY -1;//SOF
            for(i=0; i < N_CAM; i=i+1) begin
              random[i] <= #DELAY 0;
              ctr[i] <= #DELAY 1;//SOF
            end
            state <= #DELAY INTER2INTRA;
          end
        end
        
        INTER2INTRA: begin
          random_offset <= #DELAY 0;
          random[0] <= #DELAY 512;
          random[1] <= #DELAY 1024;
          random[2] <= #DELAY 2048;
          for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
          state <= #DELAY INTRAFRAME;
        end

        INTRAFRAME:
          if(!ready_r[1] || fifo_full) begin
            random_offset <= #DELAY 0;
            random[0] <= #DELAY 512;
            random[1] <= #DELAY 1024;
            random[2] <= #DELAY 2048;
            for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
            state <= #DELAY ERROR;
          end else begin
            for(i=0; i < N_CAM; i=i+1) begin
              random[i] <= #DELAY {random[i][0+:LFSR_SIZE-1]
                //12 bit implementation
                , !(random[i][11]^random[i][10]^random[i][9]^random[i][3])};
              ctr[i] <= #DELAY ctr[i] + `TRUE;
            end
            
            if(ctr[0] == (2**LFSR_SIZE-2)) begin
              //The last random number sequence in LFSR implementation
              for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;

              if(random_offset > (N_PATCH - 2**12)) begin //rolling over
                //Completely done with N_PATCH, ^EOF
                for(i=0; i < N_CAM; i=i+1) begin
                  random[i] <= #DELAY 0;
                  ctr[i] <= #DELAY 0;
                end
                random_offset <= #DELAY -2;//EOF
                state <= #DELAY INTERFRAME;
              end else begin
                random_offset <= #DELAY random_offset + (2**LFSR_SIZE-1);
                state <= #DELAY INTRAFRAME;
              end
            end
          end

        default: begin
          random_offset <= #DELAY 0;
          random[0] <= #DELAY 512;
          random[1] <= #DELAY 1024;
          random[2] <= #DELAY 2048;
          for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
          state <= #DELAY ERROR;
        end
      endcase
    end
endmodule
