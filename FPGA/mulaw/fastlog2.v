module fast_log2#(parameter DELAY=1, FP_SIZE=1)
( input CLK, RESET, valid, input[FP_SIZE-1:0] x
, output rdy, output[FP_SIZE-1:0] result);
`include "function.v"
  wire[FP_SIZE-1:0] value, exponent, exponent_d, f1, f2, f3, f4;
  wire f1_rdy, f2_rdy, f3_rdy, f4_rdy, exponent_rdy
    , exponent_fifo_empty, exponent_fifo_full;

  localparam FEXPONENT_SIZE = 8
    , FSUB_LATENCY = 11, FMULT_LATENCY = 6, I2F_LATENCY = 5
    , F2_LATENCY = FMULT_LATENCY + FSUB_LATENCY;
  reg [FP_SIZE-1:0] value_d[F2_LATENCY-1:0];
  reg [FEXPONENT_SIZE:0] i8_d;

  assign value = {x[FP_SIZE-1] //The sign bit
                , 8'd127 //exponent = 0
                , x[0+:(FP_SIZE-1 - FEXPONENT_SIZE)]};//the fraction

  fmult f1_module(.clk(CLK) // f1 = 0.3333333f * value
    , .operation_nd(valid), .a(value), .b('h3eaaaaab)
    , .result(f1), .rdy(f1_rdy));
  fsub f2_module(.clk(CLK) // f2 = 2.0f - f1
    , .operation_nd(f1_rdy), .a('h40000000)
    , .b(f1), .result(f2), .rdy(f2_rdy));
  fmult f3_module(.clk(CLK) // f3 = f2 * value
    , .operation_nd(f2_rdy), .a(f2), .b(value_d[F2_LATENCY-1])
    , .result(f3), .rdy(f3_rdy));
  fsub f4_module(.clk(CLK) // f4 = f3 - 0.66666f
    , .operation_nd(f3_rdy), .a(f3), .b('h3f2aaaab)
    , .result(f4), .rdy(f4_rdy));
  i82f i2f(.clk(CLK)
    , .operation_nd(i8_d[FEXPONENT_SIZE]), .a(i8_d[0+:FEXPONENT_SIZE])
    , .rdy(exponent_rdy), .result(exponent));

  //Store calculated exponent till f4_rdy
  f32_fifo exponent_fifo(.clk(CLK), .rst(RESET)
    , .din(exponent), .wr_en(exponent_rdy), .full(exponent_fifo_full)
    , .rd_en(f4_rdy), .dout(exponent_d), .empty(exponent_fifo_empty)
    , .sbiterr(), .dbiterr());
  fadd f5_module(.clk(CLK) // f5 = f4 + exponent
    , .operation_nd(f4_rdy && !exponent_fifo_empty), .a(f4), .b(exponent_d)
    , .result(result), .rdy(rdy));

  integer i;
  always @(posedge CLK) begin
    value_d[0] <= #DELAY value;
    for(i=1; i < F2_LATENCY; i=i+1) value_d[i] <= #DELAY value_d[i-1];
    
    //Extract the exponent (8 bits, starting from the 2nd to the left)
    i8_d <= #DELAY {valid, x[(FP_SIZE-2)-:FEXPONENT_SIZE] - 8'd128};
    //i8_d[1] <= #DELAY i8_d[0] - 8'd128;
  end
endmodule
