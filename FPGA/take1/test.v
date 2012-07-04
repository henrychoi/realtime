`timescale 1ns / 1ns

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   19:30:09 07/03/2012
// Design Name:   take1
// Module Name:   C:/private/realtime/FPGA/take1/test.v
// Project Name:  take1
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: take1
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test;
  reg clk, reset;
	// Outputs
	wire [1:0] led5;

	// Instantiate the Unit Under Test (UUT)
	take1 uut(.clk(clk), .reset(reset), .LEDs_Positions_TRI_O(led5));

	initial begin
		// Initialize Inputs
    clk = 0;
    reset = 1;
		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
    reset = 0;
	end

  always begin
    #5 clk = ~clk; //Toggle clock every 5 ticks
  end
endmodule

