`timescale 1ps/1ps
module application#(parameter ADDR_WIDTH=1, APP_DATA_WIDTH=1, N_MATCHER=4)
(input reset, dram_clk, output reg error, heartbeat, app_done
, input app_rdy, output reg app_en, output[2:0] app_cmd
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren
, output[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
, input bus_clk
, input pc_msg_pending, output reg pc_msg_ack, input[31:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[63:0] fpga_msg
, input clk_85);
`include "function.v"
  localparam START_ADDR = 27'h000_0000, END_ADDR = 27'h3ff_fffc;
  localparam DRAM_WRWAIT = 1, DRAM_WR = 2, DRAM_RD = 3, DRAM_ERROR = 0
    , DRAM_N_STATE = 4;
  localparam ADDR_INC = 7'h4;// Front and back of BL8 burst skips by 0x8
  reg[log2(DRAM_N_STATE)-1:0] dram_state;
  reg bread;
  reg[/*APP_DATA_WIDTH-1*/31:0] expected_data, wr_data;

  localparam CAPTURE_INIT = 0, CAPTURE_STANDBY = 1, CAPTURE_ARMED = 2
    , CAPTURE_CAPTURING = 3, N_CAPTURE_STATE = 4;
  localparam CL_0 = 2'h0, CL_1 = 2'h1, CL_2 = 2'h2, CL_INTERLINE = 2'h3
    , N_CL_STATE = 4;
  reg[log2(N_CAPTURE_STATE)-1:0] capture_state;

  localparam N_FRAME_SIZE = 20, N_STRIDE_SIZE = 32 - N_FRAME_SIZE
      , N_ROW_SIZE = 11, N_COL_SIZE = 12, N_FULL_SIZE = 3;
  wire[N_FRAME_SIZE-1:0] n_frame;
  reg[N_FRAME_SIZE-1:0] bus_frame, cl_frame;
  reg[N_STRIDE_SIZE:0] n_stride, cl_stride;
  reg[N_ROW_SIZE-1:0] n_row;
  reg[N_COL_SIZE-1:0] l_col, r_col;
  reg[log2(N_CL_STATE)-1:0] cl_state;
  reg[1:0] app_rdy_cl;
  reg[7:0] cl_buffer_top, cl_buffer_btm;
  wire cl_fval, cl_lval;
  wire[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
          , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  reg fval_d, lval_d;
  reg[47:0] pixel_top, pixel_btm;
  wire pixel012_valid, pixel3_valid;
  wire[11:0] matched_pixel[N_MATCHER-1:0];
  reg[N_COL_SIZE-1:0] macher_start_col[N_MATCHER-1:0];
  reg[N_MATCHER-1:0] matched_pixel_ack, matcher_init, matcher_top;
  wire[N_MATCHER-1:0] matched_pixel_pending, matched_pixel_valid
    , matched_pixel_bit00, matched_pixel_bit01, matched_pixel_bit02
    , matched_pixel_bit03, matched_pixel_bit04, matched_pixel_bit05
    , matched_pixel_bit06, matched_pixel_bit07, matched_pixel_bit08
    , matched_pixel_bit09, matched_pixel_bit10, matched_pixel_bit11
    , matcher_start_col_b00, matcher_start_col_b01, matcher_start_col_b02
    , matcher_start_col_b03, matcher_start_col_b04, matcher_start_col_b05
    , matcher_start_col_b06, matcher_start_col_b07, matcher_start_col_b08
    , matcher_start_col_b09, matcher_start_col_b10, matcher_start_col_b11
    ;
  
  PatchRowMatcher#(.N_COL_SIZE(N_COL_SIZE))
    matcher[N_MATCHER-1:0](.cl_clk(clk_85), .reset(reset)
    , .init_en(matcher_init), .bTop_in(matcher_top)
    , .start_col_b00(matcher_start_col_b00)
    , .start_col_b01(matcher_start_col_b01)
    , .start_col_b02(matcher_start_col_b02)
    , .start_col_b03(matcher_start_col_b03)
    , .start_col_b04(matcher_start_col_b04)
    , .start_col_b05(matcher_start_col_b05)
    , .start_col_b06(matcher_start_col_b06)
    , .start_col_b07(matcher_start_col_b07)
    , .start_col_b08(matcher_start_col_b08)
    , .start_col_b09(matcher_start_col_b09)
    , .start_col_b10(matcher_start_col_b10)
    , .start_col_b11(matcher_start_col_b11)
    , .l_col(l_col), .r_col(r_col)
    , .pixel012_valid(pixel012_valid), .pixel3_valid(pixel3_valid)
    , .pixel_top(pixel_top), .pixel_btm(pixel_btm)
    , .rd_clk(dram_clk), .pixel_ack(matched_pixel_ack)
    , .somepixel_pending(matched_pixel_pending)
    , .matched_pixel_valid(matched_pixel_valid)
    , .matched_pixel_b00(matched_pixel_bit00)//What a pain:
    , .matched_pixel_b01(matched_pixel_bit01)//All because the Verilog module
    , .matched_pixel_b02(matched_pixel_bit02)//array instantiation syntax
    , .matched_pixel_b03(matched_pixel_bit03)//can't carry an array of bus, I
    , .matched_pixel_b04(matched_pixel_bit04)//have to break up an array of
    , .matched_pixel_b05(matched_pixel_bit05)//bus as simple buses, and then
    , .matched_pixel_b06(matched_pixel_bit06)//do the plumbing in a generate
    , .matched_pixel_b07(matched_pixel_bit07)//statement (see below).
    , .matched_pixel_b08(matched_pixel_bit08)
    , .matched_pixel_b09(matched_pixel_bit09)
    , .matched_pixel_b10(matched_pixel_bit10)
    , .matched_pixel_b11(matched_pixel_bit11));
    
  genvar i;
  generate for(i = 0; i < N_MATCHER; i = i + 1) begin: assign_bus_to_array
      assign matched_pixel[i] = {
          matched_pixel_bit11[i], matched_pixel_bit10[i]
        , matched_pixel_bit09[i], matched_pixel_bit08[i]
        , matched_pixel_bit07[i], matched_pixel_bit06[i]
        , matched_pixel_bit05[i], matched_pixel_bit04[i]
        , matched_pixel_bit03[i], matched_pixel_bit02[i]
        , matched_pixel_bit01[i], matched_pixel_bit00[i]};
      assign matcher_start_col_b11[i] = macher_start_col[i][11];
      assign matcher_start_col_b10[i] = macher_start_col[i][10];
      assign matcher_start_col_b09[i] = macher_start_col[i][9];
      assign matcher_start_col_b08[i] = macher_start_col[i][8];
      assign matcher_start_col_b07[i] = macher_start_col[i][7];
      assign matcher_start_col_b06[i] = macher_start_col[i][6];
      assign matcher_start_col_b05[i] = macher_start_col[i][5];
      assign matcher_start_col_b04[i] = macher_start_col[i][4];
      assign matcher_start_col_b03[i] = macher_start_col[i][3];
      assign matcher_start_col_b02[i] = macher_start_col[i][2];
      assign matcher_start_col_b01[i] = macher_start_col[i][1];
      assign matcher_start_col_b00[i] = macher_start_col[i][0];
    end
  endgenerate

  clsim cl(.reset(reset), .cl_fval(cl_fval)
    , .cl_z_lval(cl_lval), .cl_z_pclk(clk_85)
    , .cl_port_a(cl_port_a), .cl_port_b(cl_port_b), .cl_port_c(cl_port_c)
    , .cl_port_d(cl_port_d), .cl_port_e(cl_port_e)
    , .cl_port_f(cl_port_f), .cl_port_g(cl_port_g), .cl_port_h(cl_port_h)
    , .cl_port_i(cl_port_i), .cl_port_j(cl_port_j));

  // Corss from camera link clock tp PCIe bus clock
  xb_rd_fifo xb_rd_fifo(.wr_clk(clk), .rd_clk(cl_clk)//, .rst(reset)
    , .din(fpga_msg), .wr_en(fpga_msg_valid && xb_rd_open)
    , .rd_en(xb_rd_rden), .dout(xb_rd_data)
    , .full(fpga_msg_full), .empty(xb_rd_empty));

  initial begin // for simulation
    macher_start_col[0] <= 1; matcher_top[0] <= `TRUE;
    matched_pixel_ack[0] <= `TRUE;
    matcher_init[0] <= `FALSE;
    macher_start_col[1] <= 2; matcher_top[1] <= `FALSE;
    matched_pixel_ack[1] <= `TRUE;
    matcher_init[1] <= `FALSE;

    #200000 matcher_init[0] <= `TRUE;
            matcher_init[1] <= `TRUE;
    #300000 matcher_init[0] <= `FALSE;
            matcher_init[1] <= `FALSE;
  end
  
  assign pixel012_valid = cl_state != CL_INTERLINE;
  assign pixel3_valid = cl_state == CL_0;
  
  always @(posedge reset, posedge clk_85)
    if(reset) begin
      fval_d <= 0; lval_d <= 0;
      l_col <= ~0; r_col <= 0;
      cl_state <= CL_INTERLINE;
    end else begin
      fval_d <= cl_fval; lval_d <= cl_lval;

      if(cl_lval)
        case(cl_state)
          CL_INTERLINE, CL_0: begin
            pixel_top <= {cl_port_a, cl_port_b, cl_port_c, cl_port_d
              , cl_port_e[7:4], 12'b0};
            cl_buffer_top[3:0] <= cl_port_e[3:0];
            pixel_btm <= {cl_port_f, cl_port_g, cl_port_h, cl_port_i
              , cl_port_j[7:4], 12'b0};
            cl_buffer_btm[3:0] <= cl_port_j[3:0];
            l_col <= r_col + 1'b1; r_col <= r_col + 2'd3;
            cl_state <= CL_1;
          end
          CL_1: begin
            pixel_top <= {cl_buffer_top[3:0]
              , cl_port_a, cl_port_b, cl_port_c, cl_port_d, 12'b0};
            cl_buffer_top[7:0] <= cl_port_e;
            pixel_btm <= {cl_buffer_btm[3:0]
              , cl_port_f, cl_port_g, cl_port_h, cl_port_i, 12'b0};
            cl_buffer_btm[7:0] <= cl_port_j;
            l_col <= r_col + 1'b1; r_col <= r_col + 2'd3;
            cl_state <= CL_2;
          end
          CL_2: begin
            pixel_top <= {cl_buffer_top
              , cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e};
            pixel_btm <= {cl_buffer_btm
              , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j};
            l_col <= r_col + 1'b1; r_col <= r_col + 3'd4;
            cl_state <= CL_0;
          end
        endcase
      else begin // !LVAL
        l_col <= ~0; r_col <= ~0;
        cl_state <= CL_INTERLINE;
      end
    end//cl_85

  always @(posedge reset, posedge cl_fval)
    if(reset) begin
      cl_frame <= 0;
      n_stride <= 0;
    end else begin
      case(capture_state)
        CAPTURE_ARMED: cl_frame <= bus_frame;
        CAPTURE_CAPTURING: begin
          if(!n_stride) cl_frame <= cl_frame - 1'b1;
          n_stride <= n_stride == cl_stride ? 0 : n_stride + 1'b1;
        end
        default: cl_frame <= 0;
      endcase
    end
    
  always @(posedge reset, posedge cl_lval)
    if(reset) n_row <= 0;
    else n_row <= fval_d ? n_row + 1'b1 : 0;
    
  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      //pc_msg_ack <= `FALSE;
      capture_state <= CAPTURE_INIT;
      bus_frame <= 0;
      app_done <= `FALSE;
      cl_stride <= {N_STRIDE_SIZE{1'b1}};
    end else begin
      // Cross from DRAM logic clock domain to camera link clock domain
      app_rdy_cl[1] <= app_rdy_cl[0]; app_rdy_cl[0] <= app_rdy;
      
      //pc_msg_ack <= `FALSE;
      app_done <= `FALSE;

      case(capture_state)
        CAPTURE_INIT: if(app_rdy_cl[1]) capture_state <= CAPTURE_STANDBY;
        CAPTURE_STANDBY: begin
          bus_frame <= 1;//pc_msg[N_FRAME_SIZE-1:0];
          cl_stride <= 1;//pc_msg[31:N_FRAME_SIZE] - 1'b1;
          capture_state <= CAPTURE_ARMED;
        end
        CAPTURE_ARMED:
          if(cl_frame) capture_state <= CAPTURE_CAPTURING;
        CAPTURE_CAPTURING:
          if(!cl_frame) begin
            capture_state <= CAPTURE_STANDBY;//If done sending, CAPTURE_STANDBY
            app_done <= `TRUE;
          end
        default: bus_frame <= 0;
      endcase//capture_state
    end//posedge clk
  end//always

  assign app_cmd = {2'b00, bread};
  assign app_wdf_data = {{(APP_DATA_WIDTH-32){1'b0}}, wr_data};

  always @(posedge dram_clk)
    if(reset) begin
      expected_data <= 1;
      error <= `FALSE;
      heartbeat <= `FALSE;
  		app_addr <= START_ADDR;
      app_en <= `TRUE;
      bread <= `FALSE;
      app_wdf_wren <= `FALSE;
      wr_data <= 0;
      dram_state <= DRAM_WRWAIT;
      pc_msg_ack <= `FALSE;
      fpga_msg_valid <= `FALSE;
      fpga_msg <= 0;
    end else begin
      if(app_rd_data_valid) begin
        if(app_rd_data[31:0] != expected_data) begin
          error <= `TRUE;
          dram_state <= DRAM_ERROR;
        end
        expected_data <= expected_data + `TRUE;
      end
      
      case(dram_state)
        DRAM_WRWAIT: begin
          if(app_rdy && app_wdf_rdy) begin
            app_en <= `FALSE;
            app_wdf_wren <= `TRUE;
            dram_state <= DRAM_WR;
            wr_data <= wr_data + `TRUE;
          end
        end
        DRAM_WR: begin
   			  app_wdf_wren <= `FALSE;
			    if(app_addr == END_ADDR) begin
			      app_addr <= START_ADDR;
				    bread <= `TRUE;
				    app_en <= `TRUE;
			      dram_state <= DRAM_RD;
			    end else begin
			      app_addr <= app_addr + ADDR_INC;
				    bread <= `FALSE;
				    app_en <= `TRUE;
				    dram_state <= DRAM_WRWAIT;
			    end
        end
        DRAM_RD: begin
          if(app_rdy) begin
				    if(app_addr == END_ADDR) begin
					    app_addr <= START_ADDR;
              bread <= `FALSE;
              app_en <= `TRUE;
              heartbeat <= ~heartbeat;
              dram_state <= DRAM_WRWAIT;
            end else begin
              app_addr <= app_addr + ADDR_INC;
              app_en <= `TRUE;
              dram_state <= DRAM_RD;
            end
          end
        end
        default: begin
          app_en <= `FALSE;
          bread <= `FALSE;
          app_wdf_wren <= `FALSE;
          error <= `TRUE;
        end
      endcase
    end
endmodule
