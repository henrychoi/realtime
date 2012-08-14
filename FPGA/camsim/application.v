module application#(parameter SIMULATION=0)
(input CLK_P, CLK_N, reset
  , output reg pc_msg_ack
  , input pc_msg_pending, input[31:0] pc_msg
  , output[3:0] led);
  `include "function.v"
  localparam STANDBY = 0, ARMED = 1, CAPTURING = 2, N_CAPTURE_STATE = 3;
  localparam CL0 = 2'h0, CL1 = 2'h1, CL2 = 2'h2, INTERLINE = 2'h3
    , N_CL_STATE = 4;
  reg[log2(N_CAPTURE_STATE)-1:0] capture_state;
  wire cl_fval, cl_lval, cl_pclk;
  wire[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
          , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  wire bus_clk, ram_clk;
  reg capture_done;
  reg fval_d, lval_d;
  wire dram_wr_fifo_full, dram_wr_fifo_empty, dram_wr_fifo_wren;
  reg dram_wr_fifo_rden;
  wire[255:0] dram_wr_fifo_din, dram_wr_fifo_dout;

  localparam N_FRAME_SIZE = 20, N_STRIDE_SIZE = 32 - N_FRAME_SIZE
      , N_LINE_SIZE = 12, N_CLK_SIZE = 10, N_FULL_SIZE = 3;
  wire[N_FRAME_SIZE-1:0] n_frame;
  reg[N_FRAME_SIZE-1:0] bus_frame, cl_frame;
  reg[N_STRIDE_SIZE:0] n_stride, cl_stride;
  reg[N_LINE_SIZE-1:0] n_line;
  reg[N_FULL_SIZE-1:0] n_full;
  reg[log2(N_CL_STATE)-1:0] cl_state;
  reg[4:0] cl0_header; 
  reg[3:0] cl1_header;
  reg[39:0] cl0_top, cl1_top, cl0_btm, cl1_btm;

  clk125MHz clk125(.CLK_IN1_P(CLK_P), .CLK_IN1_N(CLK_N), .CLK_OUT1(bus_clk));
  IBUFGDS ibufgds(.O(ram_clk), .I(CLK_P), .IB(CLK_N));
  clsim cl(CLK_P, CLK_N, reset, cl_fval, cl_lval, cl_pclk
    , cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
    , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j);

  generate
    if(SIMULATION) dram_wr_fifo_bram dram_wr_fifo(
        .wr_clk(cl_pclk), .rd_clk(ram_clk)
        , .din(dram_wr_fifo_din), .wr_en(dram_wr_fifo_wren)
        , .rd_en(dram_wr_fifo_rden), .dout(dram_wr_fifo_dout)
        , .full(dram_wr_fifo_full), .empty(dram_wr_fifo_empty));
    else dram_wr_fifo dram_wr_fifo(
        .rst(reset), .wr_clk(cl_pclk), .rd_clk(ram_clk)
        , .din(dram_wr_fifo_din), .wr_en(dram_wr_fifo_wren)
        , .rd_en(dram_wr_fifo_rden), .dout(dram_wr_fifo_dout)
        , .full(dram_wr_fifo_full), .empty(dram_wr_fifo_empty));
  endgenerate
  
  assign led = {4{`FALSE}};
  assign n_frame = bus_frame - cl_frame;
  assign dram_wr_fifo_din = {n_full                                  // 3b
    , cl0_header, cl1_header, /* cl2_header: */ CL2, cl_fval, cl_lval//13b
    , cl0_top, cl1_top, cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a
    , cl0_btm, cl1_btm, cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f};
  assign dram_wr_fifo_wren = cl_frame && !n_stride
    && ((cl_lval && cl_state == CL2)//finishing 1 full TX cycle
        || (!cl_lval && lval_d && (cl_state != CL0)));// pick up the remainder

  always @(posedge reset, posedge cl_pclk)
    if(reset) begin
      n_full <= 0;
      fval_d <= 0; lval_d <= 0;
      cl_state <= INTERLINE;
      cl0_header <= 0; cl1_header <= {CL1, `FALSE, `FALSE};
      cl0_top <= 0; cl1_top <= 0;
      cl0_btm <= 0; cl1_btm <= 0;
    end else begin
      fval_d <= cl_fval; lval_d <= cl_lval;
      n_full <= dram_wr_fifo_full && dram_wr_fifo_wren ? n_full + 1'b1 : 0;

      if(cl_lval)
        case(cl_state)
          INTERLINE, CL0: begin
            cl0_header <= {~fval_d, cl_state, cl_fval, cl_lval};
            //Zero these out in case I have to flush early
            cl1_header <= {CL1, `FALSE, `FALSE};
            cl0_top <= {cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a};
            cl0_btm <= {cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f};
            cl_state <= CL1;
          end
          CL1: begin
            cl1_header <= {cl_state, cl_fval, cl_lval};
            cl1_top <= {cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a};
            cl1_btm <= {cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f};
            cl_state <= CL2;
          end
          CL2: begin
            cl_state <= CL0;
          end
        endcase
      else cl_state <= INTERLINE;
    end//cl_pclk

  always @(posedge reset, posedge cl_fval)
    if(reset) begin
      cl_frame <= 0;
      n_stride <= 0;
    end else begin
      case(capture_state)
        ARMED: cl_frame <= bus_frame;
        CAPTURING: begin
          if(!n_stride) cl_frame <= cl_frame - 1'b1;
          n_stride <= n_stride == cl_stride ? 0 : n_stride + 1'b1;
        end
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
      capture_done <= `FALSE;
      cl_stride <= {N_STRIDE_SIZE{1'b1}};
    end else begin
      pc_msg_ack <= `FALSE;
      capture_done <= `FALSE;

      case(capture_state)
        STANDBY:
          if(pc_msg_pending && !pc_msg_ack) begin // Process the message
            if(pc_msg[31:N_FRAME_SIZE]) begin
              bus_frame <= pc_msg[N_FRAME_SIZE-1:0];
              cl_stride <= pc_msg[31:N_FRAME_SIZE] - 1'b1;
              capture_state <= ARMED;
            end
            pc_msg_ack <= `TRUE;
          end
        ARMED:
          if(cl_frame) capture_state <= CAPTURING;
        CAPTURING:
          if(!cl_frame) begin
            capture_state <= STANDBY;//If done sending, STANDBY
            capture_done <= `TRUE;
          end
        default: bus_frame <= 0;
      endcase//capture_state
    end//posedge clk
  end//always
  
endmodule
