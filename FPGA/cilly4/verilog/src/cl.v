`define TRUE 1'b1
`define FALSE 1'b0

module cl(input reset, bus_clk
  , input pc_msg_pending, output reg pc_msg_ack
  , input[31:0] pc_msg, input fpga_msg_full
  , output[127:0] fpga_msg, output fpga_msg_valid, output reg cl_done
  , input cl_clk, cl_lval, cl_fval
  , input[39:0] cl_data_top, cl_data_btm
  , output[2:0] led);
  localparam STANDBY = 0, ARMED = 1, CAPTURING = 2, MAX_STATE = 3;
  localparam N_FRAME_SIZE = 20, N_LINE_SIZE = 12, N_CLK_SIZE = 10
      , N_FULL_SIZE = 2;
  `include "function.v"
  reg[log2(MAX_STATE)-1:0] capture_state;
  wire[N_FRAME_SIZE-1:0] n_frame;
  reg[N_FRAME_SIZE-1:0] bus_frame, cl_frame;
  reg[N_LINE_SIZE-1:0] n_line;
  reg[N_CLK_SIZE-1:0] n_clk;
  reg[N_FULL_SIZE-1:0] n_full;
  reg fval_d, lval_d;
  reg[39:0] data_top_d, data_btm_d;
  wire[59:0] data_top, data_btm;
  reg[1:0] tx_state;

  assign n_frame = bus_frame - cl_frame;
  assign data_top = tx_state == 2 ?
      {data_top_d, cl_data_top[39:20]}: {data_top_d[19:0], cl_data_top};
  assign data_btm = tx_state == 2 ?
      {data_btm_d, cl_data_btm[39:20]}: {data_btm_d[19:0], cl_data_btm};
      
  assign fpga_msg = {tx_state //2b
                   , cl_fval, (n_frame == 0), cl_lval, (n_line == 0) //4b
                   , n_full //2b
                   , data_top, data_btm}; //120b
  assign fpga_msg_valid = cl_frame && tx_state != 0;//&& cl_lval && cl_fval 
  assign led = {fpga_msg_full, fpga_msg_valid, cl_fval};

  always @(posedge reset, posedge cl_clk)
    if(reset) begin
      n_full <= 0;
      fval_d = 0; lval_d = 0;
      n_clk <= 0;
      data_top_d <= 0; data_btm_d <= 0;
      tx_state <= 0;
    end else begin
      fval_d = cl_fval; lval_d = cl_lval;
      n_full <= (capture_state == CAPTURING && fpga_msg_full)
        ? n_full + 1'b1 : 0;
      n_clk <= cl_lval ? n_clk + 1'b1 : 0;
      data_top_d <= cl_data_top; data_btm_d <= cl_data_btm;
      if(!lval_d) tx_state <= 0;
      else tx_state <= tx_state ? tx_state - 1'b1 : 2;
    end

  always @(posedge reset, posedge cl_fval)
    if(reset) begin
      cl_frame <= 0;
    end else begin
      case(capture_state)
        ARMED: cl_frame <= bus_frame;
        CAPTURING: cl_frame <= cl_frame - 1'b1;
        default: cl_frame <= 0;
      endcase
    end
    
  always @(posedge reset, posedge cl_lval)
    if(reset) n_line <= 0;
    else n_line <= fval_d ? n_line + 1'b1 : 0;

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg_ack <= `FALSE;
      capture_state <= STANDBY;
      bus_frame <= 0;
      cl_done <= `FALSE;
    end else begin
      pc_msg_ack <= `FALSE;
      cl_done <= `FALSE;
      
      case(capture_state)
        STANDBY:
          if(pc_msg_pending && !pc_msg_ack) begin // Process the message
            if(pc_msg[31:N_FRAME_SIZE] == 'h1) begin
              capture_state <= ARMED;
              bus_frame <= pc_msg[N_FRAME_SIZE-1:0];
            end
            pc_msg_ack <= `TRUE;
          end
        ARMED:
          if(cl_frame) capture_state <= CAPTURING;
        CAPTURING:
          if(!cl_frame) begin
            capture_state <= STANDBY;//If done sending, STANDBY
            cl_done <= `TRUE;
          end
        default: bus_frame <= 0;
      endcase//capture_state
    end//posedge clk
  end//always

endmodule
