`define TRUE 1'b1
`define FALSE 1'b0
`timescale 1ns / 200ps

module cl_tf;
  reg cl_fval // Let's say this ticks at 10 ms period
    //, cl_x_lval, cl_x_pclk, 
    //, cl_y_pclk, cl_y_lval
    , cl_z_pclk, cl_z_lval; // cl_z_pclk 85 MHz
  reg[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  wire[7:0] GPIO_LED;
  reg bus_clk, reset;// bus_clk ticks at 250 MHz
  wire cl_pclk, cl_lval;
  
`define FRAME_NUM_SIZE 20
  reg[`FRAME_NUM_SIZE-1:0] frame_num;
`define LINE_NUM_SIZE 12 // Enough for 1080 lines from Andor camera
  reg[`LINE_NUM_SIZE-1:0] line_num;

  reg bSend;  
  reg[31:0] pc_msg32;

  reg wr_32_wren;
  wire wr_32_full, wr_32_open;
  reg[31:0] wr_32_data;
  // Wires related to /dev/xillybus_read_32
  wire rd_32_rden, rd_32_empty, rd_32_open;
  wire[31:0] rd_32_data;
  reg pc_msg32_ack; //send ACK into FIFO to clear incoming data
  wire pc_msg32_empty, xb_rd_fifo_full;
    
  fifo_bram32b xb_wr_fifo(.rst(reset), .wr_clk(bus_clk), .rd_clk(cl_pclk)
    , .din(wr_32_data), .wr_en(wr_32_wren)
    , .rd_en(pc_msg32_ack), .dout(pc_msg32)
    , .full(wr_32_full), .empty(pc_msg32_empty));

  fifo_big232 xb_rd_fifo(.rst(reset), .wr_clk(cl_pclk), .rd_clk(bus_clk)
    , .din({12'h0, frame_num
          , cl_port_b, cl_port_a, 4'b0, line_num
          , cl_port_f, cl_port_e, cl_port_d, cl_port_c
          , cl_port_j, cl_port_i, cl_port_h, cl_port_g}) 
    , .wr_en(cl_lval && bSend)
    , .rd_en(rd_32_rden), .dout(rd_32_data)
    , .full(xb_rd_fifo_full), .empty(rd_32_empty));

  assign cl_lval = cl_z_lval;
  assign cl_pclk = cl_z_pclk;

	initial begin
    bus_clk = 1'b0;
    cl_z_pclk = 1'b0;
    frame_num = 0;
    line_num = 0;
    pc_msg32 = 0;
    bSend = `FALSE;
    cl_z_lval = 1'b0;
    cl_fval = 1'b0;
    wr_32_wren = 1'b0;
		reset = 1'b0;
    #2 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
    #2 wr_32_data = 32'h1234;
    wr_32_wren = 1'b1;
    #2 wr_32_wren = 1'b0;
    #4 pc_msg32 = 32'h01020304;
    #8 cl_fval = 1'b1;
    cl_z_lval = 1'b1;
    cl_port_a = 8'h1A; cl_port_b = 8'h1B; cl_port_c = 8'h1C; cl_port_d = 8'h1D;
    cl_port_e = 8'h1E; cl_port_f = 8'h1F; cl_port_g = 8'h9; cl_port_h = 8'h6;
    cl_port_i = 8'h1; cl_port_j = 8'h7;
	end
  
  always #2 bus_clk = ~bus_clk;
  always #6 cl_z_pclk = ~cl_z_pclk;

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg32_ack <= `FALSE;
    end else begin
      pc_msg32_ack <= `FALSE;
      if(!pc_msg32_empty && !pc_msg32_ack) begin
        // Process the message
        pc_msg32_ack <= `TRUE;
      end
    end//posedge clk
  end//always

  always @(posedge reset, posedge cl_fval) begin
    if(reset) begin
      bSend <= `FALSE;
      frame_num <= 0;
      //fval_lval <= 3'b000;
    end else begin
      if(pc_msg32 == 32'h01020304) bSend <= `TRUE;
      else if(bSend) bSend <= `FALSE;
      frame_num <= frame_num + 1'b1;
      //Q: does LVAL go high with FVAL?
      //fval_lval <= {cl_x_lval, cl_y_lval, cl_z_lval};
    end//posedge cl_fval
  end//always

  always @(posedge cl_fval, posedge cl_lval) begin
    if(cl_fval) line_num <= 0;
    else line_num <= line_num + 1'b1;
  end//always

endmodule

