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
  reg fval_d, lval_d;

  assign fpga_msg = {line_num, frame_num // 32b
                     , 6'b0, clk_count   // 16b
                     , cl_data};         // 80b
  assign fpga_msg_valid = frame_num && state == CAPTURING && cl_lval;

  always @(posedge reset, posedge cl_clk)
    if(reset) begin
      fval_d <= `FALSE;
      lval_d <= `FALSE;
    end else begin
      fval_d <= cl_fval;
      lval_d <= cl_lval;
    end

  always @(posedge reset, posedge cl_fval)
    if(reset) begin
      frame_num <= 0;
    end else begin
      if(state == CAPTURING) frame_num <= frame_num + 1'b1;
      else frame_num <= 0;
    end
    
  always @(posedge reset, posedge cl_lval)
    if(reset) line_num <= 0;
    else
      if(!fval_d) line_num <= 0;
      else line_num <= line_num + 1'b1;

  always @(posedge reset, posedge cl_clk)
    if(reset) clk_count <= 0;
    else
      if(!lval_d) clk_count <= 0;
      else clk_count <= clk_count + 1'b1;

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg_ack <= `FALSE;
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
