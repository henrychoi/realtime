`timescale 10ns / 1ns
module main(input [4:0] button5, input [7:0] switch8,
    output [4:0] led5, output [7:0] led8);
  assign led5 = button5;
  assign led8 = switch8;
endmodule
