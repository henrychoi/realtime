`define TRUE 1'b1
`define FALSE 1'b0

localparam STANDBY = 2'b0, CAPTURING = 1'b1, MAX_STATE = 2;
localparam FRAME_NUM_SIZE = 20, LINE_NUM_SIZE = 12, CLK_COUNT_SIZE = 10;

module cl(input reset, bus_clk
  , input pc_msg_pending, output reg pc_msg_ack
  , input[31:0] pc_msg, input fpga_msg_overflow
  , output[127:0] fpga_msg, output fpga_msg_valid
  , input cl_clk, cl_lval, cl_fval
  , input[79:0] cl_data
  , output[3:0] led);
  `include "function.v"
  reg[log2(MAX_STATE)-1:0] state;
  reg[FRAME_NUM_SIZE-1:0] frame_num;
  reg[LINE_NUM_SIZE-1:0] line_num;
  reg[CLK_COUNT_SIZE-1:0] clk_count;

  assign fpga_msg = {cl_data};
  always @(posedge reset, posedge cl_fval) begin
    line_num <= 0;
    clk_count <= 0;
    if(reset) begin
      frame_num <= 0;
      //fval_lval <= 3'b000;
    end else begin
      frame_num <= frame_num + 1'b1;
      //Q: does LVAL go high with FVAL?
      //fval_lval <= {cl_x_lval, cl_y_lval, cl_z_lval};
    end//posedge cl_fval
  end//always

  always @(posedge cl_lval) line_num <= line_num + 1'b1;
  always @(posedge cl_clk) clk_count <= clk_count + 1'b1;

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg_ack <= `FALSE;
      //pc_msg32 <= 32'hFFFFFFFF;
      state <= STANDBY;
    end else begin
      pc_msg_ack <= `FALSE;
      if(pc_msg_pending && !pc_msg_ack) begin
        // Process the message
        if(pc_msg == 32'h1) state <= CAPTURING;
        pc_msg_ack <= `TRUE;
      end
    end//posedge clk
  end//always
endmodule
