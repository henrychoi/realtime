`timescale 10ns / 1ns
module bench;
  reg CLK_P, CLK_N, reset;
	reg [4:0] button5;
	reg [7:0] switch8;

	// Outputs
	wire [4:0] led5;
	wire [7:0] led8;

	// Instantiate the Unit Under Test (UUT)
	main uut (.CLK_P(CLK_P), .CLK_N(CLK_N), .reset(reset), 
		.button5(button5), .switch8(switch8), .led5(led5), .led8(led8));

	initial begin
		CLK_P = 0; CLK_N = 1;
		reset = 0; button5 = 0; switch8 = 0;

    #2 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
  end
  
  always begin
    #1 CLK_P = ~CLK_P;
    #0 CLK_N = ~CLK_N;
  end
endmodule

