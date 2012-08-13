module application#(parameter SIMULATION=1)
(input CLK_P, CLK_N, reset
  , output reg pc_msg_ack
  , input pc_msg_pending, input[31:0] pc_msg
  , output[3:0] led);
  `include "function.v"
  localparam STANDBY = 0, ARMED = 1, CAPTURING = 2, MAX_STATE = 3;
  reg[log2(MAX_STATE)-1:0] capture_state;
  wire cl_fval, cl_lval, cl_pclk;
  wire[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
          , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  wire bus_clk, ram_clk;
  reg capture_done;
  reg fval_d, lval_d;
  wire dram_wr_fifo_full, dram_wr_fifo_wren;
  wire[255:0] dram_fifo_din;

  localparam N_FRAME_SIZE = 20, N_STRIDE_SIZE = 32 - N_FRAME_SIZE
      , N_LINE_SIZE = 12, N_CLK_SIZE = 10, N_FULL_SIZE = 4;
  wire[N_FRAME_SIZE-1:0] n_frame;
  reg[N_FRAME_SIZE-1:0] bus_frame, cl_frame;
  reg[N_STRIDE_SIZE:0] n_stride, cl_stride;
  reg[N_LINE_SIZE-1:0] n_line;
  reg[N_FULL_SIZE-1:0] n_full;
  reg[1:0] tx_state;
  reg[3:0] tx0_header, tx2_header, tx1_header;
  reg[39:0] tx0_top, tx2_top, tx1_top, tx0_btm, tx2_btm, tx1_btm;

  clk125MHz dsClkBuf(.CLK_IN1_P(CLK_P), .CLK_IN1_N(CLK_N), .CLK_OUT1(bus_clk));
  IBUFGDS dsClkBuf(.O(ram_clk), .I(CLK_P), .IB(CLK_N));
  clsim cl(CLK_P, CLK_N, reset, cl_fval, cl_lval, cl_pclk
    , cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
    , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j);

  generate
    if(SIMULATION)
    else
      dram_wr_fifo dram_wr_fifo(.rst(reset), .wr_clk(cl_pclk), .rd_clk(ram_clk)
        , .din(din), .wr_en(wr_en) // input wr_en
        , .rd_en(rd_en), .dout(dout)
        , .full(full), .empty(empty));
    end
  endgenerate
  
  assign led = {4{`FALSE}};
  assign n_frame = bus_frame - cl_frame;
  assign dram_wr_fifo_din = {n_full                          //  4b
    , tx0_header, tx2_header, tx1_header                     // 12b
    , tx0_top, tx2_top, tx1_top, tx0_btm, tx2_btm, tx1_btm}; //240b
  assign dram_wr_fifo_wren = cl_frame && !n_stride
    && ((cl_lval && tx_state==1)//finishing 1 full TX cycle
        || (!cl_lval && lval_d));

  always @(posedge reset, posedge cl_pclk)
    if(reset) begin
      n_full <= 0;
      fval_d = 0; lval_d = 0;
      tx_state <= 0;
      tx0_header <= 0; tx2_header <= 0; tx1_header <= 0;
      tx0_top <= 0; tx2_top <= 0; tx1_top <= 0;
      tx0_btm <= 0; tx2_btm <= 0; tx1_btm <= 0;
    end else begin
      fval_d = cl_fval; lval_d = cl_lval;
      n_full <= dram_fifo_full ? n_full + 1'b1 : 0;

      case(tx_state)
        0: begin
          tx0_header <= {cl_fval, cl_lval, !fval_d, !lval_d};
          tx2_header <= 0; tx1_header <= 0; //Zero these out in case I have to flush
          tx0_top <= {cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a};
          tx0_btm <= {cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f};
        end
        2: begin
          tx2_header <= {cl_fval, cl_lval, !fval_d, !lval_d};
          tx2_top <= {cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a};
          tx2_btm <= {cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f};
        end
        1: begin
          tx1_header <= {cl_fval, cl_lval, !fval_d, !lval_d};
          tx1_top <= {cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a};
          tx1_btm <= {cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f};
        end
        default: begin // This is an error actually
          tx0_header <= 0; tx2_header <= 0; tx1_header <= 0;
          tx0_top <= 0; tx2_top <= 0; tx1_top <= 0;
          tx0_btm <= 0; tx2_btm <= 0; tx1_btm <= 0;
        end
      endcase
      
      if(!lval_d) tx_state <= 0;
      else tx_state <= tx_state ? tx_state - 1'b1 : 2;
    end

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
            bus_frame <= pc_msg[N_FRAME_SIZE-1:0];
            cl_stride <= pc_msg[31:N_FRAME_SIZE] - 1'b1;
            capture_state <= ARMED;
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
