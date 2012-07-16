`timescale 1ns / 200ps
module cl_tf;
  reg reset, cl_fval, cl_x_pclk, cl_x_lval
    , cl_y_pclk, cl_y_lval, cl_z_pclk, cl_z_lval;
  wire[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  wire[7:0] led8;
  
  reg PCIE_PERST_B_LS, PCIE_REFCLK_N, PCIE_REFCLK_P;
  reg[3:0] PCIE_RX_N, PCIE_RX_P;
  wire[3:0] PCIE_TX_N, PCIE_TX_P;

	cl uut(.CLK_P(), .CLK_N(), .reset(reset)
    , .cl_fval(cl_fval) //These come from Camera Link
    , .cl_x_pclk(cl_x_pclk), .cl_x_lval(cl_x_lval)
    , .cl_y_pclk(cl_y_pclk), .cl_y_lval(cl_y_lval)
    , .cl_z_pclk(cl_z_pclk), .cl_z_lval(cl_z_lval)
    , .cl_port_a(0), .cl_port_b(0), .cl_port_c(0), .cl_port_d(0), .cl_port_e(0)
    , .cl_port_f(0), .cl_port_g(0), .cl_port_h(0), .cl_port_i(0), .cl_port_j(0)
    , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) //The host's master bus reset
    , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
    , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
    , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
    , .GPIO_LED(led8) // For debugging
    //, output[4:0] led5
  );

	initial begin
		reset = 1'b0;
    #2 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
	end      
endmodule

