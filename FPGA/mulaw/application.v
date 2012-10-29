module application#(parameter DELAY=1, FP_SIZE=1, N_PATCH=1)
( input CLK, RESET
, input[log2(N_PATCH-1)-1:0] patch_num, input[FP_SIZE-1:0] x);
`include "function.v"
  localparam MU = 'h40800000 //4.0f
    , BIAS = 'hC2480000 //-50.0f
    , LOG2xCEILING_DIVLOG1PMU = 'h42dba522 //109.8225223f
    , ONE = 'h3f800000 //1.0f
    , FLESS_LATENCY = 2;
  reg [FP_SIZE-1:0] x_d[FLESS_LATENCY:0];
  wire[FP_SIZE-1:0] xbp1, log2_1pxb, fresult;
  wire lessThanMu, lessThanMu_rdy, xbp1_rdy, log_rdy, fresult_rdy, result_rdy
     , patch_fifo_empty, patch_fifo_full;
  reg  xb_rdy;
  wire[8:0] result;
  wire[log2(N_PATCH-1)-1:0] patch;
  
  patch_fifo fifo(.clk(CLK), .rst(RESET)
    , .din(patch_num), .wr_en(!RESET),.full()
    ,  .rd_en(result_rdy), .dout(patch), .empty(patch_fifo_empty)
    , .sbiterr(), .dbiterr());
  
  fless ltmu_module(.clk(CLK), .a(x), .b(MU), .operation_nd(!RESET)
    , .result(lessThanMu), .rdy(lessThanMu_rdy));

  fadd xbp1_module(.clk(CLK) //xbp1 = x_d[FLESS_LATENCY] + 1.0f
    , .a(ONE), .b(x_d[FLESS_LATENCY]), .operation_nd(xb_rdy)
    , .result(xbp1), .rdy(xbp1_rdy));
    
  fast_log2#(.DELAY(DELAY), .FP_SIZE(FP_SIZE))
    fast_log2(.CLK(CLK), .RESET(RESET), .valid(xbp1_rdy), .x(xbp1)
            , .result(log2_1pxb), .rdy(log_rdy));
            
  fmult fmult(.clk(CLK)
    , .a(LOG2xCEILING_DIVLOG1PMU), .b(log2_1pxb), .operation_nd(log_rdy)
    , .result(fresult), .rdy(fresult_rdy));
    
  f2byte f2byte(.clk(CLK), .a(fresult), .operation_nd(fresult_rdy)
    , .result(result), .rdy(result_rdy));

  integer i;
  always @(posedge CLK) begin
    x_d[0] <= #DELAY x;
    for(i=1; i < FLESS_LATENCY; i=i+1) x_d[i] <= #DELAY x_d[i-1];

    if(RESET) begin
      xb_rdy <= #DELAY `FALSE;
    end else begin
      x_d[FLESS_LATENCY] <= #DELAY lessThanMu_rdy && lessThanMu
        ? x_d[FLESS_LATENCY-1][FP_SIZE-1] ? 0 : x_d[FLESS_LATENCY-1]
        : MU;
      xb_rdy <= #DELAY lessThanMu_rdy;
    end
  end//always
endmodule
