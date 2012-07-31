module cl(input reset, bus_clk
  , input pc_msg_pending, output reg pc_msg_ack
  , input[31:0] pc_msg, input fpga_msg_full
  , output[31:0] fpga_msg, output fpga_msg_valid, output reg cl_done
  , input cl_clk, cl_lval, cl_fval
  , input[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j
  , output[2:0] led);
`include "function.v"
  localparam STANDBY = 0, ARMED = 1, CAPTURING = 2, MAX_STATE = 3;
  localparam N_FRAME_SIZE = 20, N_LINE_SIZE = 12, N_CLK_SIZE = 10
      , N_FULL_SIZE = 2;
  reg[log2(MAX_STATE)-1:0] capture_state;
  wire[N_FRAME_SIZE-1:0] n_frame;
  reg[N_FRAME_SIZE-1:0] bus_frame, cl_frame;
  reg[N_LINE_SIZE-1:0] n_line;
  reg[N_CLK_SIZE-1:0] n_clk;
  reg[N_FULL_SIZE-1:0] n_full;
  reg fval_d, lval_d;
  reg[1:0] tx_state;
  reg[1:0] cl_top_d, cl_btm_d;
  wire[31:0] tx1, tx2, tx0;
  wire[3:0] header;
  
  assign n_frame = bus_frame - cl_frame;
  assign header= {tx_state, cl_fval, cl_lval}; //4b
  assign tx0 = {header, 4'h0, n_line, 2'h0, n_clk
        //, cl_port_a[7:4], cl_port_b[3:0], cl_port_d[7:4], cl_port_e[3:2]//14b
        //, cl_port_f[7:4], cl_port_g[3:0], cl_port_i[7:4], cl_port_j[3:2]//14b
        };
  assign tx2 = {header, 4'h0, n_line, 2'h0, n_clk
        //, cl_top_d, cl_port_b[7:4], cl_port_c[3:0], cl_port_e[7:4]//14b
        //, cl_btm_d, cl_port_g[7:4], cl_port_h[3:0], cl_port_i[7:4]//14b
        };
  assign tx1 = {header, (n_frame == 0), (n_line == 0), n_full
        , n_line, 2'h0, n_clk
        //, cl_port_a[3:0], cl_port_c[7:4], cl_port_d[3:0] //12b
        //, cl_port_f[3:0], cl_port_h[7:4], cl_port_i[3:0] //12b
        };
  assign fpga_msg = (tx_state == 0) ? tx0 : (tx_state == 1) ? tx1 : tx2;  
  assign fpga_msg_valid = cl_frame
      && (cl_lval || ((tx_state == 2) && lval_d ));// && cl_fval 
  assign led = {fpga_msg_full, fpga_msg_valid, cl_fval};

  always @(posedge reset, posedge cl_clk)
    if(reset) begin
      n_full <= 0;
      fval_d = 0; lval_d = 0;
      n_clk <= 0;
      cl_top_d <= 0; cl_btm_d <= 0;
      tx_state <= 0;
    end else begin
      fval_d = cl_fval; lval_d = cl_lval;
      n_full <= (capture_state == CAPTURING && fpga_msg_full)
        ? n_full + 1'b1 : 0;
      n_clk <= cl_lval ? n_clk + 1'b1 : 0;
      cl_top_d <= cl_port_e[1:0]; cl_btm_d <= cl_port_j[1:0];

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
