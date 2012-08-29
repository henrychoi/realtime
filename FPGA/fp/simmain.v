`timescale 100ps/1ps
module simmain;
`include "function.v"
  reg clk, reset, standard2reduced_en, sub_en, standard_sub_en;
  reg[31:0] f32_1, f32_2;
  reg[11:0] top_0;
  wire[31:0] f32_0;
  wire[19:0] reduced0, f20_0, f20_1, f20_2, ftop_0, f20_result;
  wire DNreduce_rdy, mult_rdy;
  //, stadard2reduced_rdy, sub_rdy, f0_rdy, invalid_op
  //  , f32_0_rdy, stadard_sub_rdy;

  standard_sub standard_sub(.clk(clk)//, .sclr(reset)
    //, .invalid_op(invalid_op), .operation_nd(standard_sub_en)
    //, .operation_rfd(stadard_sub_rdy), .rdy(f32_0_rdy)
    , .a(f32_1), .b(f32_2), .result(f32_0));
  standard2reduced reduce0(.clk(clk)
    //, .operation_nd(standard2reduced_en)
    //, .operation_rfd(stadard2reduced_rdy), .rdy(reduced_rdy)
    , .a(f32_0), .result(reduced0));
  standard2reduced reduce1(.clk(clk), .a(f32_1), .result(f20_1));
  standard2reduced reduce2(.clk(clk), .a(f32_2), .result(f20_2));
  sub sub(.clk(clk)
    //, .operation_nd(sub_en), .operation_rfd(sub_rdy), .rdy(f0_rdy)
    , .a(f20_1), .b(f20_2), .result(f20_0));
  DN2reduced dn_reduce0(.clk(clk), .rdy(DNreduce_rdy)
    , .a(top_0), .result(ftop_0));
  mult mult20(.clk(clk), .rdy(mult_rdy), .a(ftop_0), .b(f20_0)
    , .result(f20_result));
  
  initial begin
    reset = `FALSE;
    clk = `TRUE;
    
    // See http://gregstoll.dyndns.org/~gregstoll/floattohex/
    //standard0 = 'h3f800000; //1.0
    sub_en <= `FALSE;
    standard_sub_en <= `FALSE;
    standard2reduced_en <= `FALSE;
#50 reset = `TRUE;
#100 reset = `FALSE;
#50 //standard_sub_en <= `TRUE;
    standard2reduced_en <= `TRUE;
    sub_en <= `TRUE;
#50 standard_sub_en <= `FALSE;
  end
  always clk = #25 ~clk;
  always @(posedge reset, posedge clk) begin
    if(reset) begin
      f32_1 <= 'h40400000;//3.0
      f32_2 <= 'h3dcccccd;//0.1
      top_0 <= 2000;
    end else begin
      f32_1 <= f32_1 - 13'h1000;
      top_0 <= top_0 - 1'b1;
    end
  end
endmodule

