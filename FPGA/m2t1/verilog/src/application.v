`timescale 1ps/1ps
module application#(parameter ADDR_WIDTH=1, APP_DATA_WIDTH=1
, PIXEL_SIZE=12)
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

  reg[APP_DATA_WIDTH-1:0] dram_data;
  localparam PATCH_SIZE = 6, WEIGHT_SIZE=16
    , ROW_SUM_SIZE = log2(PATCH_SIZE) + PIXEL_SIZE + WEIGHT_SIZE
    , PATCH_SUM_SIZE=log2(PATCH_SIZE**PATCH_SIZE) + PIXEL_SIZE + WEIGHT_SIZE
    , N_ROW_REDUCER = 10, N_PATCH_REDUCER = 6, N_PATCH = 81742;
  reg[N_ROW_REDUCER-1:0] row_init, row_sum_ack;
  wire[N_ROW_REDUCER-1:0] row_sum_rdy;
  wire[ROW_SUM_SIZE-1:0] row_sum[N_ROW_REDUCER-1:0];
  // This index bridges the row reducer to the patch reducer
  wire[log2(N_PATCH_REDUCER)-1:0] owner_reducer[N_ROW_REDUCER-1:0];
  reg[N_PATCH_REDUCER-1:0] patch_init, patch_sum_ack;
  wire[PATCH_SUM_SIZE-1:0] patch_sum[N_PATCH_REDUCER-1:0];
  wire[N_PATCH_REDUCER-1:0] patch_sum_rdy;
  //Each patch reducer needs to remember what patch it is working for,
  //because a patch reducer is recycled for another patch after the sum is
  //calculated.
  reg[log2(N_PATCH)-1:0] patch_id[N_PATCH_REDUCER-1:0];
  //Use these registers to move the bits from PatchRowReducer to the
  //corresponding PatchReducer after the PatchRowReducer produces the partial
  //sum.
  reg[ROW_SUM_SIZE-1:0] partial_sum[N_PATCH_REDUCER-1:0];
  reg[N_PATCH_REDUCER-1:0] partial_sum_valid;
  
  genvar i;
  generate
    for(i = 0; i < N_PATCH_REDUCER; i = i + 1) begin
      PatchReducer#(.PATCH_SIZE(PATCH_SIZE), .N_PATCH(N_PATCH)
        , .ROW_SUM_SIZE(ROW_SUM_SIZE), .PATCH_SUM_SIZE(PATCH_SUM_SIZE))
        patch_reducer(.reset(reset), .dram_clk(dram_clk)
        , .init(patch_init[i]), .patch_id(patch_id[i])
        , .partial_sum(partial_sum[i]), .partial_sum_valid(partial_sum_valid[i])
        , .sum_ack(patch_sum_ack[i]), .sum_rdy(patch_sum_rdy[i])
        , .sum(patch_sum[i]));
    end
    
    for(i = 0; i < N_ROW_REDUCER; i = i + 1) begin
      PatchRowReducer#(.APP_DATA_WIDTH(APP_DATA_WIDTH)
        , .N_COL_SIZE(N_COL_SIZE), .PATCH_SIZE(PATCH_SIZE)
        , .ROW_SUM_SIZE(ROW_SUM_SIZE), .N_PATCH_REDUCER(N_PATCH_REDUCER))
        row_reducer(.cl_clk(clk_85), .l_col(l_col), .r_col(r_col)
        , .pixel012_valid(pixel012_valid), .pixel3_valid(pixel3_valid)
        , .pixel_top(pixel_top), .pixel_btm(pixel_btm)
        , .dram_clk(dram_clk), .reset(reset)
        , .init(row_init[i]), .config_data(dram_data)
        , .sum(row_sum[i]), .sum_ack(row_sum_ack[i]), .sum_rdy(row_sum_rdy[i])
        , .owner_reducer(owner_reducer[i]));
    end
  endgenerate
  
  clsim cl(.reset(reset), .cl_fval(cl_fval)
    , .cl_z_lval(cl_lval), .cl_z_pclk(clk_85)
    , .cl_port_a(cl_port_a), .cl_port_b(cl_port_b), .cl_port_c(cl_port_c)
    , .cl_port_d(cl_port_d), .cl_port_e(cl_port_e)
    , .cl_port_f(cl_port_f), .cl_port_g(cl_port_g), .cl_port_h(cl_port_h)
    , .cl_port_i(cl_port_i), .cl_port_j(cl_port_j));

  // Corss from camera link clock tp PCIe bus clock
  xb_rd_fifo xb_rd_fifo(.wr_clk(dram_clk), .rd_clk(bus_clk)//, .rst(reset)
    , .din(fpga_msg), .wr_en(fpga_msg_valid && xb_rd_open)
    , .rd_en(xb_rd_rden), .dout(xb_rd_data)
    , .full(fpga_msg_full), .empty(xb_rd_empty));

  initial begin // for simulation
#     0 dram_data <= 0;
#     0 row_init[0] <= `FALSE;
#350000 row_init[0] <= `TRUE;
        dram_data <= {
            12'h15, 16'h15 //dark[5],weight[5]
          , 12'h14, 16'h14 //dark[4],weight[4]
          , 12'h13, 16'h13 //dark[3],weight[3]
          , 12'h12, 16'h12 //dark[2],weight[2]
          , 12'h11, 16'h11 //dark[1],weight[1]
          , 12'h10, 16'h10 //dark[0],weight[0]
          , 12'd1, `TRUE   //start_col_d, bTop_d; bits [22:10]
          , 10'd0 //owner_reducer ID, NOT the patch_id.
                  //Has to be size log2(N_PATCH_REDUCER).
          };
#  5000 row_init[0] <= `FALSE;
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
