`timescale 100ps/1ps

module main#(parameter N_MULT=10)(input clk, reset, output reg error);
`include "function.v"
  integer i;
  reg[N_MULT-1:0] mult_avail;
  wire[N_MULT-1:0] mult_rdy;
  reg[log2(N_MULT)-1:0] mult_idx;
  reg[19:0] a[N_MULT-1:0], b[N_MULT-1:0];
  wire[19:0] result[N_MULT-1:0];
  
  genvar geni;
  generate
    for(geni=0; geni < N_MULT; geni=geni+1)
      mult mult(.clk(clk), .rdy(mult_rdy[geni])
      , .a(a[geni]), .b(b[geni]), .result(result[geni]));
  endgenerate
  
  always @(posedge reset, posedge clk) begin
    if(reset) begin
      error <= `FALSE;
      for(i=0; i <  N_MULT; i=i+1) begin
        mult_avail[i] <= `TRUE;
        a[i] <= 'h3f800;//1.0f
        b[i] <= 'h40000;//2.0f
      end
      mult_idx <= 0;
    end else begin
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
