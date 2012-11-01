module application#(parameter DELAY=1, FP_SIZE=1, N_PATCH=1)
( input CLK, RESET
, input[log2(N_PATCH-1)-1:0] patch_num, input[FP_SIZE-1:0] wtsum);
`include "function.v"
  localparam MU = 'h40800000 //4.0f
    , BIAS = 'hC2480000 //-50.0f
    , MUxSCALE = 'h3b254948//4.0f/(1536.0f - BIAS) = 0.002522f
    , LOG2xCEILING_DIVLOG1PMU = 'h42dba522 //109.8225223f
    , ONE = 'h3f800000 //1.0f
    , FLESS_LATENCY = 2
    , DSP_FP_SIZE = 32;
  reg [DSP_FP_SIZE-1:0] x_d[FLESS_LATENCY:0];
  wire[DSP_FP_SIZE-1:0] x, wtsum_m_bias, xbp1, log2_1pxb, fcompress;
  wire wtsum_m_bias_rdy, x_rdy
     , lessThanMu, lessThanMu_rdy
     , xbp1_rdy, log_rdy, fcompress_rdy, compress_rdy
     , patch_fifo_empty, patch_fifo_full;
  reg  xb_rdy;
  wire[8:0] compress;
  wire[log2(N_PATCH-1)-1:0] patch;
  
  //Store the patch number matching the wtsum until compander result obtained
  patch_fifo fifo(.clk(CLK), .rst(RESET)
    , .din(patch_num), .wr_en(!RESET),.full(patch_fifo_full)
    , .rd_en(compress_rdy), .dout(patch), .empty(patch_fifo_empty)
    , .sbiterr(), .dbiterr());
    
  fsub wtsum_m_bias_module(.clk(CLK) // wtsum - BIAS
    //Promote to DSP_FP_SIZE for downstream
    , .a({wtsum, {(DSP_FP_SIZE-FP_SIZE){`FALSE}}})
    , .b(BIAS), .operation_nd(!RESET)
    , .result(wtsum_m_bias), .rdy(wtsum_m_bias_rdy));
  
  fmult muscale_mult_module(.clk(CLK) // x = wtsum_m_bias * MUxSCALE
    , .a(wtsum_m_bias), .b(MUxSCALE), .operation_nd(wtsum_m_bias_rdy)
    , .result(x), .rdy(x_rdy));
  
  fless ltmu_module(.clk(CLK) // lessThanMu = x < MU
    , .a(x), .b(MU), .operation_nd(x_rdy)
    , .result(lessThanMu), .rdy(lessThanMu_rdy));

  fadd xbp1_module(.clk(CLK) //xbp1 = x_d[FLESS_LATENCY] + 1.0f
    , .a(ONE), .b(x_d[FLESS_LATENCY]), .operation_nd(xb_rdy)
    , .result(xbp1), .rdy(xbp1_rdy));
    
  fast_log2#(.DELAY(DELAY), .DSP_FP_SIZE(DSP_FP_SIZE))
    fast_log2(.CLK(CLK), .RESET(RESET) //log2_1pxb = fast_log2(xbp1)
      , .valid(xbp1_rdy), .x(xbp1), .result(log2_1pxb), .rdy(log_rdy));
            
  fmult fmult(.clk(CLK) // fcompress = LOG2xCEILING_DIVLOG1PMU * log2_1pxb
    , .a(LOG2xCEILING_DIVLOG1PMU), .b(log2_1pxb), .operation_nd(log_rdy)
    , .result(fcompress), .rdy(fcompress_rdy));
    
  f2byte f2byte(.clk(CLK) // compress = ROUND(fcompress)
    , .a(fcompress), .operation_nd(fcompress_rdy)
    , .result(compress), .rdy(compress_rdy));

  integer i;
  always @(posedge CLK) begin
    x_d[0] <= #DELAY x;
    for(i=1; i < FLESS_LATENCY; i=i+1) x_d[i] <= #DELAY x_d[i-1];

    if(RESET) begin
      xb_rdy <= #DELAY `FALSE;
    end else begin
      x_d[FLESS_LATENCY] <= #DELAY lessThanMu_rdy && lessThanMu
        ? x_d[FLESS_LATENCY-1][DSP_FP_SIZE-1] ? 0 : x_d[FLESS_LATENCY-1]
        : MU;
      xb_rdy <= #DELAY lessThanMu_rdy;
    end
  end//always
endmodule
