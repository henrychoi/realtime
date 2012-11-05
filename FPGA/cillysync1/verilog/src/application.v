module application#(parameter DELAY=1, SYNC_WINDOW=1, FP_SIZE=1, N_PATCH=1
, N_CAM=1, XB_SIZE=1)
( input CLK, RESET, output[7:4] GPIO_LED, output ready
, input[N_CAM-1:0] input_valid
, input[N_CAM*(log2(N_PATCH)+FP_SIZE)-1:0] input_data
, output reg output_valid, output reg[XB_SIZE-1:0] output_data);
`include "function.v"
  
  localparam MU = 'h40800000 //4.0f
    , BIAS = 'hC2480000 //-50.0f
    , MUxSCALE = 'h3b254948//4.0f/(1536.0f - BIAS) = 0.002522f
    , LOG2xCEILING_DIVLOG1PMU = 'h42dba522 //109.8225223f
    , ONE = 'h3f800000 //1.0f
    , FLESS_LATENCY = 2
    , DSP_FP_SIZE = 32
    , COMPRESS_SIZE = 8
    , N_FRAME_SIZE = 20
    ;
  reg [N_FRAME_SIZE-1:0] n_frame;
  reg [DSP_FP_SIZE-1:0] x_d[N_CAM-1:0][FLESS_LATENCY:0];
  wire[DSP_FP_SIZE-1:0] x[N_CAM-1:0], wtsum_m_bias[N_CAM-1:0], xbp1[N_CAM-1:0]
    , log2_1pxb[N_CAM-1:0], fcompress[N_CAM-1:0];
  wire[N_CAM-1:0] wtsum_m_bias_rdy, x_rdy
     , lessThanMu, lessThanMu_rdy
     , xbp1_rdy, log_rdy, fcompress_rdy, compress_rdy
     , patch_fifo_empty, patch_fifo_full;
  reg [N_CAM-1:0] xb_rdy, input_count;
  wire[COMPRESS_SIZE:0] compress[N_CAM-1:0];

  genvar geni, genj;
  localparam BRAM_ADDR_SIZE = 10, BRAM_DATA_SIZE = COMPRESS_SIZE
    , BRAM_END_ADDR = {BRAM_ADDR_SIZE{`TRUE}}
    , N_BRAM = 2**(log2(SYNC_WINDOW) - BRAM_ADDR_SIZE);
  reg [log2(SYNC_WINDOW)-1:0] patch0_loc, wait4patch_loc;
  wire[log2(SYNC_WINDOW)-1:0] patch_loc[N_CAM-1:0];
  wire[log2(N_PATCH)-1:0] patch_num[N_CAM-1:0], patch[N_CAM-1:0];
  wire[FP_SIZE-1:0] wtsum[N_CAM-1:0];

  reg [log2(N_PATCH)-1:0] wait4patch;//The patch num to be completed
  wire[log2(N_PATCH)-1:0] wait4patch_plus_sync_window;
  assign wait4patch_plus_sync_window = wait4patch + SYNC_WINDOW;

  wire[log2(SYNC_WINDOW)-log2(N_BRAM)-1:0] wait4patch_row;
  wire[log2(N_BRAM)-1:0] wait4patch_col;
  assign {wait4patch_row, wait4patch_col} = wait4patch_loc;

  reg [BRAM_DATA_SIZE-1:0] din[N_CAM-1:0];
  wire[BRAM_DATA_SIZE-1:0] dout[N_CAM-1:0][N_BRAM-1:0];
  //reg [FP_SIZE-1:0] sync_wtsum[N_CAM-1:0];
  reg sync_valid;
  wire wait4patch_done;
  reg [N_CAM-1:0] wr_have_bit, eof;
  reg have_bit;
  
  reg [N_BRAM-1:0] wren[N_CAM-1:0];
  reg [BRAM_ADDR_SIZE-1:0] wr_addr[N_CAM-1:0];
  wire[BRAM_ADDR_SIZE-1:0] rd_addr[N_CAM-1:0][N_BRAM-1:0];
  wire[N_BRAM-1:0] vout[N_CAM-1:0];
  //This notation more convenient to test for completion across all cams
  wire[N_CAM-1:0] have_patch[N_BRAM-1:0], is_meta, is_sof;
  
  localparam ERROR = 0, INIT = 1, SOF_WAIT = 2, INTRAFRAME = 3, N_STATE = 4;
  reg [log2(N_STATE)-1:0] state;
  assign ready = state == SOF_WAIT || state == INTRAFRAME;
  //assign output_valid = |compress_rdy;  
  assign GPIO_LED = {input_count, ready};
  
  generate
    for(geni=0; geni < N_CAM; geni=geni+1) begin: foreach_cam
      //Store the patch number matching the wtsum until compander result
      //obtained
      patch_fifo fifo(.clk(CLK), .rst(RESET)
        , .din(patch_num[geni]), .wr_en(input_valid[geni])
        , .full(patch_fifo_full[geni]), .rd_en(compress_rdy[geni])
        , .dout(patch[geni]), .empty(patch_fifo_empty[geni])
        , .sbiterr(), .dbiterr());
      
      fsub wtsum_m_bias_module(.clk(CLK) // wtsum - BIAS
        //Promote to DSP_FP_SIZE for downstream
        , .a({wtsum[geni], {(DSP_FP_SIZE-FP_SIZE){`FALSE}}})
        , .b(BIAS), .operation_nd(input_valid[geni])
        , .result(wtsum_m_bias[geni]), .rdy(wtsum_m_bias_rdy[geni]));
      
      fmult muscale_mult_module(.clk(CLK) // x = wtsum_m_bias * MUxSCALE
        , .a(wtsum_m_bias[geni]), .b(MUxSCALE)
        , .operation_nd(wtsum_m_bias_rdy[geni])
        , .result(x[geni]), .rdy(x_rdy[geni]));

      fless ltmu_module(.clk(CLK) // lessThanMu = x < MU
        , .a(x[geni]), .b(MU), .operation_nd(x_rdy[geni])
        , .result(lessThanMu[geni]), .rdy(lessThanMu_rdy[geni]));

      fadd xbp1_module(.clk(CLK) //xbp1 = x_d[FLESS_LATENCY] + 1.0f
        , .a(ONE), .b(x_d[geni][FLESS_LATENCY]), .operation_nd(xb_rdy[geni])
        , .result(xbp1[geni]), .rdy(xbp1_rdy[geni]));
        
      fast_log2#(.DELAY(DELAY), .DSP_FP_SIZE(DSP_FP_SIZE))
        fast_log2(.CLK(CLK), .RESET(RESET) //log2_1pxb = fast_log2(xbp1)
          , .valid(xbp1_rdy[geni]), .x(xbp1[geni])
          , .result(log2_1pxb[geni]), .rdy(log_rdy[geni]));

      fmult fmult(.clk(CLK) // fcompress = LOG2xCEILING_DIVLOG1PMU * log2_1pxb
        , .a(LOG2xCEILING_DIVLOG1PMU)
        , .b(log2_1pxb[geni]), .operation_nd(log_rdy[geni])
        , .result(fcompress[geni]), .rdy(fcompress_rdy[geni]));

      f2byte f2byte(.clk(CLK) // compress = ROUND(fcompress)
        , .a(fcompress[geni]), .operation_nd(fcompress_rdy[geni])
        , .result(compress[geni]), .rdy(compress_rdy[geni]));

      for(genj=0; genj < N_BRAM; genj=genj+1) begin: foreach_bram
        bram bram(.clka(CLK), .wea(wren[geni][genj]), .addra(wr_addr[geni])
                  , .dina({wr_have_bit[geni], din[geni]})
                  , .clkb(CLK), .addrb(rd_addr[geni][genj])
                  , .doutb({vout[geni][genj], dout[geni][genj]})
                  , .sbiterr(), .dbiterr(), .rdaddrecc());
        assign rd_addr[geni][genj] = wait4patch_row + (genj < wait4patch_col);
        assign have_patch[genj][geni] = vout[geni][genj] == have_bit;
      end//for(N_BRAM)

      assign {patch_num[geni], wtsum[geni]} =
        input_data[(geni*(log2(N_PATCH)+FP_SIZE)) +: (log2(N_PATCH)+FP_SIZE)];
      assign patch_loc[geni] = patch[geni][log2(SYNC_WINDOW)-1:0] + patch0_loc;
      assign is_meta[geni] = &patch[geni][1+:(log2(N_PATCH)-1)];
      assign is_sof[geni] = patch[geni][0];
    end//for(N_CAM)
  endgenerate

  //assign output_data = input_data[0+:XB_SIZE];
  //assign output_data = {is_meta[0] && !is_sof[0], is_meta[0] && is_sof[0]
  //  , 3'b000, compress_rdy
  //  , compress[2][0+:COMPRESS_SIZE]
  //  , compress[1][0+:COMPRESS_SIZE]
  //  , compress[0][0+:COMPRESS_SIZE]};
  assign wait4patch_done = &have_patch[wait4patch_col];

  integer i, j;
  always @(posedge CLK) begin
    for(i=0; i < N_CAM; i=i+1) begin
      //Delay through register because wren is registered
      din[i] <= #DELAY compress[i][0+:COMPRESS_SIZE];
      x_d[i][0] <= #DELAY x[i];
      for(j=1; j < FLESS_LATENCY; j=j+1) x_d[i][j] <= #DELAY x_d[i][j-1];
    end

    if(RESET) begin
      n_frame <= #DELAY 0;
      input_count <= #DELAY 0;
      output_valid <= #DELAY `FALSE;
      output_data <= #DELAY 0;
      have_bit <= #DELAY `TRUE;
      for(i=0; i < N_CAM; i=i+1) begin
        wr_have_bit[i] <= #DELAY `FALSE;
        wr_addr[i] <= #DELAY 0;
        wren[i] <= #DELAY {N_BRAM{`TRUE}};
        xb_rdy[i] <= #DELAY `FALSE;
      end
      patch0_loc <= #DELAY 0;
      wait4patch_loc <= #DELAY 0;
      wait4patch <= #DELAY 0;
      sync_valid <= #DELAY `FALSE;
      eof <= #DELAY 0;
      state <= #DELAY INIT;
      //$display("%d ns: qptr %d, din %d", $time, qptr, din);
    end else begin
      output_valid <= #DELAY `FALSE; // set default values
      output_data <= #DELAY 0;

      for(i=0; i < N_CAM; i=i+1) begin
        if(input_valid[i]) input_count[i] <= #DELAY input_count[i] + `TRUE;
        
        x_d[i][FLESS_LATENCY] <= #DELAY lessThanMu_rdy[i] && lessThanMu[i]
          ? x_d[i][FLESS_LATENCY-1][DSP_FP_SIZE-1]
            ? 0 : x_d[i][FLESS_LATENCY-1]
          : MU;
        xb_rdy[i] <= #DELAY lessThanMu_rdy[i];
      end

      case(state)
        INIT: begin // Write the starting valid bit to BRAM
          for(i=0; i < N_CAM; i=i+1) wr_addr[i] <= #DELAY wr_addr[i] + `TRUE;
          if(wr_addr[0] == BRAM_END_ADDR) begin
            for(i=0; i < N_CAM; i=i+1) wren[i] <= #DELAY 0;
            state <= #DELAY SOF_WAIT;
          end
        end

        SOF_WAIT: begin
          eof <= #DELAY 0;
          if((compress_rdy[0] && is_meta[0] && is_sof[0])
          || (compress_rdy[1] && is_meta[1] && is_sof[1])
          || (compress_rdy[2] && is_meta[2] && is_sof[2])) begin
            n_frame <= #DELAY n_frame + `TRUE; // a new frame!
            output_valid <= #DELAY `TRUE;
            output_data <= #DELAY {`FALSE, `TRUE // !EOF, SOF
              , 10'h000, n_frame};
            state <= #DELAY INTRAFRAME;
          end

          if(wait4patch_done) begin
            sync_valid <= #DELAY `TRUE;
            wait4patch <= #DELAY wait4patch == (N_PATCH - 1)
              ? {log2(N_PATCH){`FALSE}} : wait4patch + `TRUE;

            wait4patch_loc <= #DELAY wait4patch_loc + `TRUE;
            if(&wait4patch_loc) have_bit <= #DELAY ~have_bit;//Rolling over

            // Emit output
            output_valid <= #DELAY `TRUE;
            output_data[N_CAM*COMPRESS_SIZE+:8] <= #DELAY
              {`FALSE, `FALSE   // !EOF, !SOF
              , 3'b000, 3'b111};// all 3 cams emitted together
            for(i=0; i < N_CAM; i=i+1) begin
              //sync_wtsum[i] <= #DELAY dout[i][wait4patch_col];
              output_data[i*COMPRESS_SIZE+:COMPRESS_SIZE] <= #DELAY
                dout[i][wait4patch_col];
            end            
          end else sync_valid <= #DELAY `FALSE;
        end
        
        INTRAFRAME: begin //Can process received data          
          if(&eof) begin // Transition to SOF_WAIT
            eof <= #DELAY 0;
            patch0_loc <= #DELAY patch0_loc + (N_PATCH % SYNC_WINDOW);
            for(i=0; i < N_CAM; i=i+1) wren[i] <= #DELAY 0;
            state <= #DELAY SOF_WAIT;
          end else if((compress_rdy[0] && !is_meta[0]
                       && patch[0] >= wait4patch_plus_sync_window)
                   || (compress_rdy[1] && !is_meta[1]
                       && patch[1] >= wait4patch_plus_sync_window)
                   || (compress_rdy[2] && !is_meta[2]
                       && patch[2] >= wait4patch_plus_sync_window))
            state <= #DELAY ERROR;

          for(i=0; i < N_CAM; i=i+1) begin
            if(compress_rdy[i] && is_meta[i] && !is_sof[i]) // EOF
              eof[i] <= #DELAY `TRUE;

            for(j=0; j < N_BRAM; j=j+1) begin
              wren[i][j] <= #DELAY compress_rdy[i] && !is_meta[i]
                         && j == patch_loc[i][0+:log2(N_BRAM)];
            end

            wr_addr[i] <= #DELAY // Pick off the MSB of the patch_loc
              patch_loc[i][log2(SYNC_WINDOW)-1:log2(N_BRAM)];
            wr_have_bit[i] <= #DELAY patch_loc[i] >= wait4patch_loc
              ? have_bit : ~have_bit;
          end

          if(wait4patch_done) begin
            sync_valid <= #DELAY `TRUE;
            wait4patch <= #DELAY wait4patch == (N_PATCH - 1)
              ? 0 : wait4patch + `TRUE;

            wait4patch_loc <= #DELAY wait4patch_loc + `TRUE;
            if(&wait4patch_loc) have_bit <= #DELAY ~have_bit;//Rolling over

            // Emit output
            output_valid <= #DELAY `TRUE;
            output_data[N_CAM*COMPRESS_SIZE+:8] <= #DELAY
              {`FALSE, `FALSE   // !EOF, !SOF
              , 3'b000, 3'b111};// all 3 cams emitted together
            for(i=0; i < N_CAM; i=i+1) begin
              //sync_wtsum[i] <= #DELAY dout[i][wait4patch_col];
              output_data[i*COMPRESS_SIZE+:COMPRESS_SIZE] <= #DELAY
                dout[i][wait4patch_col];
            end
          end else sync_valid <= #DELAY `FALSE;
        end//OK
        
        default: begin
          sync_valid <= #DELAY `FALSE;
          for(i=0; i < N_CAM; i=i+1) wren[i] <= #DELAY 0;
        end
      endcase
    end
  end//always
endmodule
