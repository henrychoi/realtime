`timescale 500ps / 100ps
`include "dpp.v"
module test;
  reg clk, reset;
`define TIMER_SIZE 3
  reg signed [`TIMER_SIZE:0] t;

  //wire[1:0] led5;
	dining_table uut(.clk(clk), .reset(reset) //, .LEDs_Positions_TRI_O(led5)
    );

	initial begin
		clk = 1'b0;
		reset = 1'b0;
    t <= 3; //0;        
    //$monitor($time, " clk=%b", clk);
    #5 reset = 1'b1;//The rising of reset line should trigger the reset logic
		#5 reset = 1'b0;
	end
  
   always begin
     #5 clk = ~clk;
     t <= t - 1;
   end

  always @(posedge t[`TIMER_SIZE]) begin // detect rollover
    t <= 3;
  end//always @(posedge clk or posedge reset) 

endmodule

