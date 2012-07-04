`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:50:28 07/03/2012
// Design Name:   dining_table
// Module Name:   C:/private/realtime/FPGA/DPP/test.v
// Project Name:  DPP
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: dining_table
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////
`include "dpp.v"

module test;

	// Inputs
	reg clk;
	reg reset;

	// Outputs
	wire[2:0] led5;

	// Instantiate the Unit Under Test (UUT)
	dining_table #(.N_PHILO(2))uut (
		.clk(clk), 
		.reset(reset), 
		.LEDs_Positions_TRI_O(led5)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		reset = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
    #5 reset = 1;
	end
  
  always begin
    #5 clk = ~clk; //Toggle clock every 5 ticks
  end
endmodule

