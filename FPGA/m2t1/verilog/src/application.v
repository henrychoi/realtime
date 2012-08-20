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
  reg[11:0] pixel_top[3:0], pixel_btm[3:0], matched_pixel[N_MATCHER-1:0];
  wire pixel012_valid, pixel3_valid, matched_pixel_pending[N_MATCHER-1:0];
  reg matched_pixel_ack[N_MATCHER-1:0]
  
  PatchRowMatcher#(.N_COL_SIZE(N_COL_SIZE))
    matcher[N_MATCHER-1:0](.cl_clk(clk_85), .reset(reset)
    , .l_col(l_col), .r_col(r_col);
    , .pixel012_valid(pixel012_valid), .pixel3_valid(pixel3_valid)
    , .pixel_top(pixel_top), .pixel_btm(pixel_btm)
    , .rd_clk(dram_clk), .pixel_ack(matched_pixel_ack)
    , .pixel_pending(matched_pixel_pending), .pixel(matched_pixel));

  clsim cl(.reset(reset), .cl_fval(cl_fval)
    , .cl_z_lval(cl_lval), .cl_z_pclk(clk_85)
    , .cl_port_a(cl_port_a), .cl_port_b(cl_port_b), .cl_port_c(cl_port_c)
    , .cl_port_d(cl_port_d), .cl_port_e(cl_port_e)
    , .cl_port_f(cl_port_f), .cl_port_g(cl_port_g), .cl_port_h(cl_port_h)
    , .cl_port_i(cl_port_i), .cl_port_j(cl_port_j));

  assign pixel012_valid = cl_state != CL_INTERLINE;
  assign pixel3_valid = cl_state == CL_0;
  
  always @(posedge reset, posedge clk_85)
    if(reset) begin
      fval_d <= 0; lval_d <= 0;
      l_col <= 0; r_col <= 0;
      cl_state <= CL_INTERLINE;
    end else begin
      fval_d <= cl_fval; lval_d <= cl_lval;

      if(cl_lval)
        case(cl_state)
          CL_INTERLINE, CL_0: begin
            pixel_top[0] <= {cl_port_a, cl_port_b[7:4]};
            pixel_top[1] <= {cl_port_b[3:0], cl_port_c};
            pixel_top[2] <= {cl_port_d, cl_port_e[7:4]};
            cl_buffer_top[3:0] <= cl_port_e[3:0];
            pixel_btm[0] <= {cl_port_f, cl_port_g[7:4]};
            pixel_btm[1] <= {cl_port_g[3:0], cl_port_h};
            pixel_btm[2] <= {cl_port_i, cl_port_j[7:4]};
            cl_buffer_btm[3:0] <= cl_port_j[3:0];
            l_col <= r_col; r_col <= r_col + 2'd3;
            cl_state <= CL_1;
          end
          CL_1: begin
            pixel_top[0] <= {cl_buffer_top[3:0], cl_port_a};
            pixel_top[1] <= {cl_port_b, cl_port_c[7:4]};
            pixel_top[2] <= {cl_port_c[3:0], cl_port_d};
            cl_buffer_top[7:0] <= cl_port_e;
            pixel_btm[0] <= {cl_buffer_btm[3:0], cl_port_f};
            pixel_btm[1] <= {cl_port_g, cl_port_h[7:4]};
            pixel_btm[2] <= {cl_port_h[3:0], cl_port_i};
            cl_buffer_btm[7:0] <= cl_port_j;
            l_col <= r_col; r_col <= r_col + 2'd3;
            cl_state <= CL_2;
          end
          CL_2: begin
            pixel_top[0] <= {cl_buffer_top, cl_port_a[7:4]};
            pixel_top[1] <= {cl_port_a[3:0], cl_port_b};
            pixel_top[2] <= {cl_port_c, cl_port_d[7:4]};
            pixel_top[3] <= {cl_port_d[3:0], cl_port_e};
            pixel_btm[0] <= {cl_buffer_btm, cl_port_f[7:4]};
            pixel_btm[1] <= {cl_port_f[3:0], cl_port_g};
            pixel_btm[2] <= {cl_port_h, cl_port_i[7:4]};
            pixel_btm[3] <= {cl_port_i[3:0], cl_port_j};
            l_col <= r_col; r_col <= r_col + 3'd4;
            cl_state <= CL_0;
          end
        endcase
      else begin
        l_col <= 0; r_col <= 0;
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
