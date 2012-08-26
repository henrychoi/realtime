`timescale 1ps/1ps
module application#(parameter ADDR_WIDTH=1, APP_DATA_WIDTH=1)
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
  integer i;
  localparam CAPTURE_INIT = 0, CAPTURE_STANDBY = 1, CAPTURE_ARMED = 2
    , CAPTURE_CAPTURING = 3, N_CAPTURE_STATE = 4;
  localparam CL_0 = 0, CL_1 = 1, CL_2 = 2, CL_INTERLINE = 3, CL_ERROR = 4
    , N_CL_STATE = 5;
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
  
  localparam DN_SIZE = 12, e_SIZE = DN_SIZE;
  reg[DN_SIZE-1:0] dn_top[3:0], dn_btm[3:0];
  wire[DN_SIZE-1:0] dark_top[3:0], dark_btm[3:0];
  wire e012_valid, e3_valid;

  wire[APP_DATA_WIDTH-1:0] dram_data;
  localparam PATCH_SIZE = 6, WEIGHT_SIZE=16
    , ROW_SUM_SIZE = log2(PATCH_SIZE) + e_SIZE + WEIGHT_SIZE
                   + 1 // double because the seam patch could generate
                       // 2 rows at the same time
    , PATCH_SUM_SIZE=log2(PATCH_SIZE**2) + e_SIZE + WEIGHT_SIZE
    , N_ROW_REDUCER = 10, N_PATCH_REDUCER = 4
    , PATCH_REDUCER_INVALID = {log2(N_PATCH_REDUCER){1'b1}}
    , N_PATCH = 81742
    ;
  //reg[N_ROW_REDUCER-1:0] row_sum_ack;
  wire[1:0] row_sum_rdy[N_ROW_REDUCER-1:0];
  reg[1:0] row_init[N_ROW_REDUCER-1:0];
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
  reg[1:0] partial_sum_valid[N_PATCH_REDUCER-1:0];
  
  localparam COEFF_KIND_END = 2'd0, COEFF_KIND_PIXEL = 2'd1
    , COEFF_KIND_ROW_REDUCER = 2'd2, COEFF_KIND_PATCH_REDUCER = 2'd3;
  wire pixel_coeff_fifo_full, pixel_coeff_fifo_high, pixel_coeff_fifo_empty;
  //reg pixel_coeff_fifo_ack;
  wire dram_rd_fifo_full, dram_rd_fifo_empty;
  reg dram_rd_fifo_ack;
  localparam COEFFRD_BELOW_HIGH = 0, COEFFRD_ABOVE_HIGH = 1, COEFFRD_FULL = 2
    , COEFFRD_N_STATE = 3;
  wire[log2(COEFFRD_N_STATE)-1:0] coeffrd_state;

  dram_rd_fifo dram_rd_fifo (.clk(dram_clk), .rst(reset)
    , .din(app_rd_data), .full(dram_rd_fifo_full)
    , .wr_en(//Note: always write into FIFO when there is DRAM data
             app_rd_data_valid && app_rd_data[1:0] != COEFF_KIND_END)
    , .rd_en(dram_rd_fifo_empty //Was there even any data to acknowledge?
             && coeffrd_state != COEFFRD_FULL)
    , .dout(dram_data), .empty(dram_rd_fifo_empty));
  
  pixel_coeff_fifo pixel_coeff_fifo(.wr_clk(dram_clk)
    , .rd_clk(cl_clk)//Read clock has to be the same as write clock in PatchRowReducer
    , .din(dram_data[193:2]) //bits 1,0 used as message kind
    , .wr_en(!pixel_coeff_fifo_full
             && dram_rd_fifo_empty
             && dram_data[1:0] == COEFF_KIND_PIXEL)
    , .rd_en(cl_lval)//Keep reading from FIFO for each cl_clk when LVAL, to keep
                     //the coefficients flowing
    , .dout({dark_top[3], dark_btm[3]
           , dark_top[2], dark_btm[2]
           , dark_top[1], dark_btm[1]
           , dark_top[0], dark_btm[0]})
    , .prog_full(pixel_coeff_fifo_high), .full(pixel_coeff_fifo_full)
    , .empty(pixel_coeff_fifo_empty));
  
  genvar geni;
  generate
    for(geni=0; geni < N_PATCH_REDUCER; geni=geni+1) begin
      PatchReducer#(.PATCH_SIZE(PATCH_SIZE)
        , .ROW_SUM_SIZE(ROW_SUM_SIZE), .PATCH_SUM_SIZE(PATCH_SUM_SIZE))
        patch_reducer(.reset(reset), .dram_clk(dram_clk)
        , .init(patch_init[geni])
        , .partial_sum(partial_sum[geni])
        , .partial_sum_valid(partial_sum_valid[geni])
        , .sum_ack(patch_sum_ack[geni]), .sum_rdy(patch_sum_rdy[geni])
        , .sum(patch_sum[geni]));
    end
    
    for(geni=0; geni < N_ROW_REDUCER; geni=geni+1) begin
      PatchRowReducer#(.APP_DATA_WIDTH(APP_DATA_WIDTH)
        , .N_COL_SIZE(N_COL_SIZE), .PATCH_SIZE(PATCH_SIZE)
        , .ROW_SUM_SIZE(ROW_SUM_SIZE), .N_PATCH_REDUCER(N_PATCH_REDUCER)
        , .PATCH_REDUCER_INVALID(PATCH_REDUCER_INVALID))
        row_reducer(.cl_clk(clk_85)
        , .l_col(l_col), .r_col(r_col)
        , .e012_valid(e012_valid), .e3_valid(e3_valid)
        , .e_top0(dn_top[0] - dark_top[0]) //dark DN loaded from pixel_coeff_fifo
        , .e_top1(dn_top[1] - dark_top[1])
        , .e_top2(dn_top[2] - dark_top[2])
        , .e_top3(dn_top[3] - dark_top[3])
        , .e_btm0(dn_btm[0] - dark_btm[0])
        , .e_btm1(dn_btm[1] - dark_btm[1])
        , .e_btm2(dn_btm[2] - dark_btm[2])
        , .e_btm3(dn_btm[3] - dark_btm[3])
        , .dram_clk(dram_clk), .reset(reset)
        , .init(row_init[geni]), .config_data(dram_data)
        , .sum(row_sum[geni]), .sum_rdy(row_sum_rdy[geni])
        , .owner_reducer(owner_reducer[geni]));
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

`ifdef FIXME
  initial begin // for simulation
#     0 dram_data <= 0;
#     0 row_init[0] <= {`FALSE, `FALSE};
        patch_init[0] <= `FALSE;
#350000 row_init[0] <= {`TRUE, `TRUE};
        dram_data <= {
            16'h15, 16'h14, 16'h13, 16'h12, 16'h11, 16'h10//weight_top
          , 16'h00, 16'h04, 16'h03, 16'h02, 16'h01, 16'h00//weight_btm
          , {{(N_COL_SIZE-1){1'b0}}, 1'b1} //start_col_d: bits[21:10]
          , {log2(N_PATCH_REDUCER){1'b0}}//owner_reducer ID, NOT the patch_id.
                                         //Has to be size log2(N_PATCH_REDUCER).
          };
#  5000 row_init[0] <= {`FALSE, `FALSE};
#  5000 patch_id[0] <= 17'd12345;
        patch_init[0] <= `TRUE;
#  5000 patch_init[0] <= `FALSE;
  end
`endif
  
  assign e012_valid = cl_state != CL_INTERLINE;
  assign e3_valid = cl_state == CL_0;
  
  always @(posedge reset, posedge clk_85)
    if(reset) begin
      fval_d <= 0; lval_d <= 0;
      l_col <= ~0; r_col <= 0;
      /* Driven by FIFO; don't need to drive them myself any more
      dark_top[0] <= 0; dark_top[1] <= 0;
      dark_top[2] <= 0; dark_top[3] <= 0;
      dark_btm[0] <= 0; dark_btm[1] <= 0;
      dark_btm[2] <= 0; dark_btm[3] <= 0; */
      cl_state <= CL_INTERLINE;
    end else begin
      fval_d <= cl_fval; lval_d <= cl_lval;
      if(cl_state != CL_ERROR) // ERROR state is a final state
        if(cl_lval) begin
          // Invariance to assert: if LVAL, but I don't have a valid pixel
          // coefficient, there is a logical error somewhere
          if(pixel_coeff_fifo_empty) cl_state <= CL_ERROR;
          else begin //!pixel_coeff_fifo_empty
            case(cl_state)
              CL_INTERLINE, CL_0: begin
                dn_top[0] <= {cl_port_a     , cl_port_b[7:4]};
                dn_top[1] <= {cl_port_b[3:0], cl_port_c     };
                dn_top[2] <= {cl_port_d     , cl_port_e[7:4]};
                dn_top[3] <= {DN_SIZE{1'b0}};
                cl_buffer_top[3:0] <= cl_port_e[3:0];
                dn_btm[0] <= {cl_port_f     , cl_port_g[7:4]};
                dn_btm[1] <= {cl_port_g[3:0], cl_port_h     };
                dn_btm[2] <= {cl_port_i     , cl_port_j[7:4]};
                dn_btm[3] <= {DN_SIZE{1'b0}};
                cl_buffer_btm[3:0] <= cl_port_j[3:0];

                l_col <= r_col + 1'b1; r_col <= r_col + 2'd3;
                cl_state <= CL_1;
              end
              CL_1: begin
                dn_top[0] <= {cl_buffer_top[3:0], cl_port_a     };
                dn_top[1] <= {cl_port_b         , cl_port_c[7:4]};
                dn_top[2] <= {cl_port_c[3:0]    , cl_port_d     };
                dn_top[3] <= {DN_SIZE{1'b0}};
                cl_buffer_top[7:0] <= cl_port_e;
                dn_btm[0] <= {cl_buffer_btm[3:0], cl_port_f     };
                dn_btm[1] <= {cl_port_g         , cl_port_h[7:4]};
                dn_btm[2] <= {cl_port_h[3:0]    , cl_port_i     };
                dn_btm[3] <= {DN_SIZE{1'b0}};
                cl_buffer_btm[7:0] <= cl_port_j;

                l_col <= r_col + 1'b1; r_col <= r_col + 2'd3;
                cl_state <= CL_2;
              end
              CL_2: begin
                dn_top[0] <= {cl_buffer_top , cl_port_a[7:4]};
                dn_top[1] <= {cl_port_a[3:0], cl_port_b     };
                dn_top[2] <= {cl_port_c     , cl_port_d[7:4]};
                dn_top[3] <= {cl_port_d[3:0], cl_port_e     };
                dn_btm[0] <= {cl_buffer_btm , cl_port_f[7:4]};
                dn_btm[1] <= {cl_port_f[3:0], cl_port_g     };
                dn_btm[2] <= {cl_port_h     , cl_port_i[7:4]};
                dn_btm[3] <= {cl_port_i[3:0], cl_port_j     };

                l_col <= r_col + 1'b1; r_col <= r_col + 3'd4;
                cl_state <= CL_0;
              end
            endcase
          end //!pixel_coeff_fifo_empty
        end else begin // !LVAL
          l_col <= ~0; r_col <= ~0;
          cl_state <= CL_INTERLINE;
        end // if(cl_lval)

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

  localparam START_ADDR = 27'h000_0000//, END_ADDR = 27'h3ff_fffc;
    , ADDR_INC = 3'd8;// BL8
  localparam DRAMIFC_ERROR = 0, DRAMIFC_READING = 1, DRAMIFC_WAIT = 2
    , DRAMIFC_INTER_FRAME = 3, DRAMIFC_N_STATE = 4;
  reg[log2(DRAMIFC_N_STATE)-1:0] dramifc_state;
  reg bread;
  reg[APP_DATA_WIDTH-1:0] wr_data;
  
  assign app_cmd = {2'b00, bread};
  assign app_wdf_data = {APP_DATA_WIDTH{1'b0}};
  assign coeffrd_state = pixel_coeff_fifo_full /* OR other FIFO full */
    ? COEFFRD_FULL
    : pixel_coeff_fifo_high /*OR other FIFO above high */
      ? COEFFRD_ABOVE_HIGH : COEFFRD_BELOW_HIGH;

  always @(posedge dram_clk)
    if(reset) begin
      error <= `FALSE;
      heartbeat <= `FALSE;

  		app_addr <= START_ADDR;
      app_en <= `TRUE;
      bread <= `TRUE;
      app_wdf_wren <= `FALSE;
      wr_data <= 0;
      dramifc_state <= DRAMIFC_READING;

      pc_msg_ack <= `FALSE;
      fpga_msg_valid <= `FALSE;
      fpga_msg <= 0;

      for(i=0; i < N_PATCH_REDUCER; i=i+1) partial_sum_valid[i] <= 0;
      
    end else begin // normal operation
    
      for(i=0; i < N_ROW_REDUCER; i=i+1)
        if(owner_reducer[i] != PATCH_REDUCER_INVALID) begin
          partial_sum[owner_reducer[i]] <= row_sum[i];
          partial_sum_valid[owner_reducer[i]] <= row_sum_rdy[i];
        end
            
      case(dramifc_state)
        DRAMIFC_ERROR: error <= `TRUE;
        DRAMIFC_READING: begin
          if(dram_rd_fifo_full) begin
            app_en <= `FALSE;
            dramifc_state <= DRAMIFC_ERROR;
          end else begin
            app_addr <= app_addr + ADDR_INC; //Keep reading till I can't
            if(app_rd_data_valid) begin
              if(app_rd_data[1:0] == COEFF_KIND_END) begin
                app_en <= `FALSE;
                dramifc_state <= DRAMIFC_INTER_FRAME;
              end else if(coeffrd_state == COEFFRD_FULL) begin
                app_en <= `FALSE;//Note: the address is already incremented
                dramifc_state <= DRAMIFC_WAIT;
              end
            end
          end
        end
        DRAMIFC_WAIT:
          if(coeffrd_state == COEFFRD_BELOW_HIGH) begin
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
        DRAMIFC_INTER_FRAME:
          if(!cl_fval && fval_d) begin //FIXME: get FVAL from cl domain to dram clock domain
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
      endcase
    end

endmodule
