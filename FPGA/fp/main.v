module main#(parameter DELAY=1, N_MULT=10)
(input clk, reset, output reg error);
`include "function.v"
  integer i;
  localparam MINUS_2 = 'hc0000000, HALF = 'h3f000000, ONE = 'h3f800000;
  
  reg[N_MULT-1:0] mult_avail;
  wire[N_MULT-1:0] mult_rdy;
  reg[log2(N_MULT)-1:0] mult_idx;
  reg[19:0] a[N_MULT-1:0], b[N_MULT-1:0];
  wire[19:0] result[N_MULT-1:0];
  
  reg [31:0] x, x_int_p1, xp1d, x_new_d[12:0];
  wire[31:0] x_new, x_int, fx_int_p1, xp1;
  wire x_new_rdy, x_int_rdy, fx_int_p1_rdy, fadd_rfd, xp1_rdy;
  reg  badd, x_int_p1_rdy;
  
  fadd faddp5(.clk(clk), .sclr(reset), .a(x), .b(HALF), .operation_nd(badd)
            , .result(x_new), .rdy(x_new_rdy));
  f2int f2int(.clk(clk), .a(x_new), .operation_nd(x_new_rdy)
            , .result(x_int), .rdy(x_int_rdy));

  fadd fadd1(.clk(clk), .sclr(reset)
           , .a(x_new), .b(ONE), .operation_nd(x_new_rdy)
           , .result(xp1), .rdy(xp1_rdy), .operation_rfd());

  int2f int2f(.clk(clk), .a(x_int_p1), .operation_nd(x_int_p1_rdy)
            , .result(fx_int_p1), .rdy(fx_int_p1_rdy));
  
  genvar geni;
  generate
    for(geni=0; geni < N_MULT; geni=geni+1)
      mult mult(.clk(clk), .rdy(mult_rdy[geni])
      , .a(a[geni]), .b(b[geni]), .result(result[geni]));
  endgenerate
  
  always @(posedge clk) begin
    if(reset) begin
      x <= #DELAY MINUS_2;
      badd <= #DELAY `FALSE;
      x_int_p1_rdy <= #DELAY `FALSE;
      
      error <= `FALSE;
      for(i=0; i <  N_MULT; i=i+1) begin
        mult_avail[i] <= `TRUE;
        a[i] <= 'h3f800;//1.0f
        b[i] <= 'h40000;//2.0f
      end
      mult_idx <= 0;
    end else begin
      badd <= #DELAY `TRUE;//~badd;
      if(x_new_rdy) x <= #DELAY x_new;
      xp1d <= #DELAY xp1;
      x_int_p1_rdy <= #DELAY x_int_rdy;
      x_int_p1 <= #DELAY x_int + `TRUE;
      
      x_new_d[0] <= #DELAY x_new;
      for(i=1; i < 13; i=i+1) x_new_d[i] <= #DELAY x_new_d[i-1];
      
      //Look for the first available mult using mult_avail
      mult_avail[mult_idx] <= `FALSE;
      if(mult_avail[0]) mult_idx <= 0;
      else if(mult_avail[1]) mult_idx <= 1;
      else if(mult_avail[2]) mult_idx <= 2;
      else if(mult_avail[3]) mult_idx <= 3;
      else if(mult_avail[4]) mult_idx <= 4;
      else if(mult_avail[5]) mult_idx <= 5;
      else if(mult_avail[6]) mult_idx <= 6;
      else if(mult_avail[7]) mult_idx <= 7;
      else if(mult_avail[8]) mult_idx <= 8;
      else if(mult_avail[9]) mult_idx <= 9;
      else error <= `TRUE;
      
    end
  end

endmodule
