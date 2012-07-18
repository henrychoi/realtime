`define TRUE 1'b1
`define FALSE 1'b0
`timescale 1ns / 200ps

module sim;
	//reg CLK_P, CLK_N
  reg reset;
	wire [7:0] GPIO_LED;
  reg bus_clk;
  reg       user_r_read_32_rden;
  wire       user_r_read_32_empty;
  wire [31:0] user_r_read_32_data;
  wire        user_r_read_32_open;
  reg        user_w_write_32_wren;
  wire        user_w_write_32_full;
  reg [31:0] user_w_write_32_data;
  reg pc_msg32_ack; // Command from the PC to FPGA
  wire[31:0] pc_msg32;
  wire pc_msg32_empty;
  reg send_data;
  reg[11:0] top_pixel, bottom_pixel;
  wire xb_rd_fifo_full;
  reg[3:0] n_msg;

  xb_wr_fifo xb_wr_fifo(.rst(reset), .clk(bus_clk)//.wr_clk(bus_clk), .rd_clk(clk)
    , .din(user_w_write_32_data), .wr_en(user_w_write_32_wren)
    , .rd_en(pc_msg32_ack), .dout(pc_msg32)
    , .full(user_w_write_32_full), .empty(pc_msg32_empty));

  xb_rd_fifo xb_rd_fifo(.rst(reset), .clk(bus_clk)//.wr_clk(clk), .rd_clk(bus_clk)
    , .din(pc_msg32), .wr_en(send_data)
    , .rd_en(user_r_read_32_rden), .dout(user_r_read_32_data)
    , .full(xb_rd_fifo_full), .empty(user_r_read_32_empty));

  assign GPIO_LED[7:4] = n_msg;

	// Instantiate the Unit Under Test (UUT)
	initial begin
    bus_clk <= 0;
    reset = 1'b0;
    user_r_read_32_rden = 0;
    user_w_write_32_wren = 0;
    send_data = 0;
    pc_msg32_ack = 0;
    
    #2 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
    
    #4 user_w_write_32_data <= 32'h30313233;
       user_w_write_32_wren <= 1'b1;
    #2 user_w_write_32_wren <= 1'b0;
	end
      
  always #1 bus_clk = ~bus_clk;
  
  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg32_ack <= 0;
      send_data <= 0;
      top_pixel <= 12'b000000010101;
      bottom_pixel <= 12'b010101000000;
      n_msg <= 0;
    end else begin
      pc_msg32_ack <= `FALSE; //Default value
      send_data <= `FALSE;
      
      if(!pc_msg32_empty && !pc_msg32_ack) begin // a message from PC!
        pc_msg32_ack <= `TRUE;
        send_data <= `TRUE;
        n_msg <= n_msg + 1'b1;
      end
    end
  end//always

endmodule
