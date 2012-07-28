`define TRUE 1'b1
`define FALSE 1'b0

localparam STANDBY = 0, ARMED = 1, CAPTURING = 2, MAX_STATE = 3;
localparam N_FRAME_SIZE = 20, N_LINE_SIZE = 12, N_CLK_SIZE = 10;

module cl(input reset, bus_clk
  , input pc_msg_pending, output reg pc_msg_ack
  , input[31:0] pc_msg, input fpga_msg_overflow
  , output[127:0] fpga_msg, output fpga_msg_valid, output reg cl_done
  , input cl_clk, cl_lval, cl_fval
  , input[79:0] cl_data
  , output[2:0] led);
  `include "function.v"
  reg[log2(MAX_STATE)-1:0] state;
  wire[N_FRAME_SIZE-1:0] n_frame;
  reg[N_FRAME_SIZE-1:0] bus_frame, cl_frame;
  reg[N_LINE_SIZE-1:0] n_line;
  reg[N_CLK_SIZE-1:0] n_clk;
  reg fval_d, lval_d;

  assign n_frame = bus_frame - cl_frame;
  assign fpga_msg = {n_line, n_frame // 32b
                   , 3'b000, cl_fval, 2'b00, n_clk   // 16b
                   , cl_data};     // 80b
  assign fpga_msg_valid = cl_frame && cl_lval;//&& state == CAPTURING;
  assign led[0] = fpga_msg_valid;

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
      cl_frame <= 0;
    end else begin
      case(state)
        ARMED: cl_frame <= bus_frame;
        CAPTURING: cl_frame <= cl_frame - 1'b1;
        default: cl_frame <= 0;
      endcase
    end
    
  always @(posedge reset, posedge cl_lval)
    if(reset) n_line <= 0;
    else n_line <= (fval_d && cl_fval) ? n_line + 1'b1 : 0;

  always @(posedge reset, posedge cl_clk)
    if(reset) n_clk <= 0;
    else n_clk <= (lval_d && cl_fval) ? n_clk + 1'b1 : 0;

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg_ack <= `FALSE;
      state <= STANDBY;
      bus_frame <= 0;
      cl_done <= `FALSE;
    end else begin
      pc_msg_ack <= `FALSE;
      cl_done <= `FALSE;
      
      case(state)
        STANDBY:
          if(pc_msg_pending && !pc_msg_ack) begin // Process the message
            if(pc_msg[31:N_FRAME_SIZE] == 'h1) begin
              state <= ARMED;
              bus_frame <= pc_msg[N_FRAME_SIZE-1:0];
            end
            pc_msg_ack <= `TRUE;
          end
        ARMED:
          if(cl_frame) state <= CAPTURING;
        CAPTURING:
          if(!cl_frame) begin
            state <= STANDBY;//If done sending, STANDBY
            cl_done <= `TRUE;
          end
        default: bus_frame <= 0;
      endcase//state
    end//posedge clk
  end//always
endmodule
