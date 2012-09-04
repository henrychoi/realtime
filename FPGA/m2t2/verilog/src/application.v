`timescale 1ps/1ps
module application#(parameter XB_SIZE=1,ADDR_WIDTH=1, APP_DATA_WIDTH=1, FP_SIZE=1)
(input reset, dram_clk, output reg error, heartbeat, app_done
, input app_rdy, output reg app_en, output[2:0] app_cmd
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
, input bus_clk
, input pc_msg_pending, output reg pc_msg_ack, input[XB_SIZE-1:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[XB_SIZE-1:0] fpga_msg
//, input clk_85
);
`include "function.v"
  integer i;
  localparam CAPTURE_ERROR = 0, CAPTURE_STANDBY = 1, CAPTURE_INTRALINE = 2
    , CAPTURE_INTERLINE = 3, CAPTURE_INTERFRAME = 4, N_CAPTURE_STATE = 5;
  reg[log2(N_CAPTURE_STATE)-1:0] capture_state;

  localparam N_PIXEL_PER_CLOCK = 2'd2, N_FRAME_SIZE = 20
    , FRAME_HEIGHT = 7, N_ROW_MAX = 2048
    , FRAME_WIDTH = 6, N_COL_MAX = 2048
    , N_FSUB_LATENCY = 8;
  reg[N_FRAME_SIZE-1:0] cl_n_frame;
  reg[log2(N_ROW_MAX)-1:0] cl_n_row, cl_n_row_d[N_FSUB_LATENCY-1:0];
  reg[log2(N_COL_MAX)-1:0] cl_n_col, cl_n_col_d[N_FSUB_LATENCY-1:0];
  
  localparam DN_SIZE = 12, N_DN2F_LATENCY = 6;
  wire pc_msg_is_dn, fval, lval, dark_sub_rdy[N_PIXEL_PER_CLOCK-1:0];
  reg[N_DN2F_LATENCY-1:0] fval_d, lval_d;
  wire[DN_SIZE-1:0] dn[N_PIXEL_PER_CLOCK-1:0];
  wire[FP_SIZE-1:0] fdn[N_PIXEL_PER_CLOCK-1:0], dark[N_PIXEL_PER_CLOCK-1:0]
    , fdark_subtracted[N_PIXEL_PER_CLOCK-1:0];

  wire[APP_DATA_WIDTH-1:0] dram_data;
  localparam PATCH_SIZE = 6
    , N_ROW_REDUCER = 10, N_PATCH_REDUCER = 100
    , PATCH_REDUCER_INVALID = {log2(N_PATCH_REDUCER){1'b1}}
    , N_PATCH = 81742
    , ROW_REDUCER_CONFIG_SIZE_IN_DRAM
      = log2(N_PATCH_REDUCER) + log2(N_COL_MAX) + PATCH_SIZE*FP_SIZE
    , ROW_REDUCER_CONFIG_SIZE = ROW_REDUCER_CONFIG_SIZE_IN_DRAM + log2(N_ROW_MAX)
    , PATCH_REDUCER_IDX_INVALID = {log2(N_PATCH_REDUCER){`TRUE}}
    , ROW_REDUCER_IDX_INVALID = {log2(N_ROW_REDUCER){`TRUE}}
    ;
  //reg[N_ROW_REDUCER-1:0] row_sum_ack;
  wire[N_ROW_REDUCER-1:0] row_sum_rdy;
  reg[N_ROW_REDUCER-1:0] row_init;
  wire[FP_SIZE-1:0] row_sum[N_ROW_REDUCER-1:0]
    , patch_sum[N_PATCH_REDUCER-1:0];
  reg[FP_SIZE-1:0] partial_sum[N_PATCH_REDUCER-1:0];
  wire[log2(N_ROW_MAX)-1:0] reducer_current_row[N_PATCH_REDUCER-1:0]
    , new_patch_top_row;
  reg[log2(N_ROW_REDUCER)-1:0] new_row_reducer_idx_r;
  reg[log2(N_ROW_MAX)-1:0] new_patch_start_row, row_reducer_init_row;
  reg[log2(N_COL_MAX)-1:0] row_reducer_init_col;
  reg[PATCH_SIZE*FP_SIZE-1:0] row_reducer_init_weights;

  // This index bridges the row reducer to the patch reducer

  wire[log2(N_PATCH_REDUCER)-1:0] new_patch_idx;
  reg[log2(N_PATCH_REDUCER)-1:0] new_patch_idx_r, owner_reducer[N_ROW_REDUCER-1:0];
  reg[N_PATCH_REDUCER-1:0] patch_init, patch_sum_ack;
  wire[N_PATCH_REDUCER-1:0] patch_sum_rdy, row_reducer_avail
    , row_reducer_avail_1, n_row_reducer_avail;
  wire coeff_sink_full, coeff_sink_high;
  //Each patch reducer needs to remember what patch it is working for,
  //because a patch reducer is recycled for another patch after the sum is
  //calculated.
  reg[log2(N_PATCH)-1:0] patch_id[N_PATCH_REDUCER-1:0];
  wire[log2(N_PATCH)-1:0] new_patch_id;
  //Use these registers to move the bits from PatchRowReducer to the
  //corresponding PatchReducer after the PatchRowReducer produces the partial
  //sum.
  reg[1:0] partial_sum_valid[N_PATCH_REDUCER-1:0];
  wire[N_PATCH_REDUCER-1:0] patch_reducer_avail;
  wire new_patch_valid;
  
  localparam COEFF_KIND_INVALID = 2'd0, COEFF_KIND_PIXEL = 2'd1
    , COEFF_KIND_ROW_REDUCER = 2'd2, COEFF_KIND_PATCH_REDUCER = 2'd3;
  wire pixel_coeff_fifo_full, pixel_coeff_fifo_high, pixel_coeff_fifo_empty
    , patch_coeff_fifo_full, patch_coeff_fifo_high, patch_coeff_fifo_empty;
  //reg pixel_coeff_fifo_ack;
  wire dram_rd_fifo_full, dram_rd_fifo_empty, dram_rd_fifo_pending;
  wire[1:0] dram_rd_coeff_kind, pc_msg_coeff_kind;
  reg dram_rd_fifo_ack;
  localparam COEFFRD_ERROR = 0, COEFFRD_BELOW_HIGH = 1, COEFFRD_ABOVE_HIGH = 2
    , COEFFRD_FULL = 3, COEFFRD_N_STATE = 4;
  reg[log2(COEFFRD_N_STATE)-1:0] coeffrd_state;
  reg[ADDR_WIDTH-1:0] end_addr;
  localparam START_ADDR = 27'h000_0000//, END_ADDR = 27'h3ff_fffc;
    , ADDR_INC = 4'd8;// BL8
  localparam DRAMIFC_ERROR = 0
    , DRAMIFC_WR1 = 1, DRAMIFC_WR2 = 2, DRAMIFC_MSG_WAIT = 3
    , DRAMIFC_WR_WAIT = 4
    , DRAMIFC_READING = 5, DRAMIFC_THROTTLED = 6, DRAMIFC_INTERFRAME = 7
    , DRAMIFC_N_STATE = 8;
  reg[log2(DRAMIFC_N_STATE)-1:0] dramifc_state;
  reg bread;
  reg[APP_DATA_WIDTH*2-1:0] tmp_data;
  reg[log2(APP_DATA_WIDTH*2-1)-1:0] tmp_data_offset;
    
  dram_rd_fifo dram_rd_fifo (.clk(dram_clk)//, .rst(reset)
    , .din(app_rd_data), .full(dram_rd_fifo_full)
    , .wr_en(//Note: always write into FIFO when there is valid DRAM data
             app_rd_data_valid //flow control done upstream by DRAMIfc
             && app_rd_data[(APP_DATA_WIDTH-2)+:2] != COEFF_KIND_INVALID)
    , .rd_en(dram_rd_fifo_pending //Was there even any data to acknowledge?
             && coeffrd_state != COEFFRD_FULL)
    , .dout(dram_data), .empty(dram_rd_fifo_empty));

  pixel_coeff_fifo pixel_coeff_fifo(.wr_clk(dram_clk), .rd_clk(dram_clk)
    , .din(dram_data[0+:(N_PIXEL_PER_CLOCK * 4 * FP_SIZE)])
    , .wr_en(!pixel_coeff_fifo_full && dram_rd_fifo_pending
             && dram_rd_coeff_kind == COEFF_KIND_PIXEL)
    , .rd_en(lval)//Keep reading from FIFO when LVAL
    , .dout({dark[0], dark[1]})
    , .prog_full(pixel_coeff_fifo_high), .full(pixel_coeff_fifo_full)
    , .empty(pixel_coeff_fifo_empty));

  patch_coeff_fifo patch_coeff_fifo(
    .wr_clk(dram_clk), .rd_clk(dram_clk)
    , .din(dram_data[0+:(4 * (1 + log2(N_PATCH) + log2(N_ROW_MAX)
                              + log2(N_PATCH_REDUCER)))])
    , .wr_en(!patch_coeff_fifo_full && dram_rd_fifo_pending
             && dram_rd_coeff_kind == COEFF_KIND_PATCH_REDUCER)
    , .rd_en(|patch_reducer_avail)
    , .dout({new_patch_valid, new_patch_id, new_patch_top_row, new_patch_idx})
    , .prog_full(patch_coeff_fifo_high), .full(patch_coeff_fifo_full)
    , .empty(patch_coeff_fifo_empty));
  
  genvar geni;
  generate
    for(geni=0; geni < N_PIXEL_PER_CLOCK; geni=geni+1) begin
      DN2f dn2f(.clk(dram_clk), .a(dn[geni]), .result(fdn[geni]));
      fsub fsub(.clk(dram_clk)
        , .a(fdn[geni]), .b(dark[geni]), .operation_nd(fval_d[N_DN2F_LATENCY-1])
        , .rdy(dark_sub_rdy[geni]), .result(fdark_subtracted[geni]));
    end
    
    for(geni=0; geni < N_PATCH_REDUCER; geni=geni+1)
      PatchReducer#(.N_ROW_SIZE(log2(N_ROW_MAX)), .PATCH_SIZE(PATCH_SIZE)
        , .FP_SIZE(FP_SIZE))
        patch_reducer(.reset(reset), .dram_clk(dram_clk)
        , .init(patch_init[geni]), .start_row(new_patch_start_row)
        , .available(patch_reducer_avail[geni])
        , .current_row(reducer_current_row[geni])
        , .partial_sum(partial_sum[geni])
        , .partial_sum_valid(partial_sum_valid[geni])
        , .sum_ack(patch_sum_ack[geni]), .sum_rdy(patch_sum_rdy[geni])
        , .sum(patch_sum[geni]));

    for(geni=0; geni < N_ROW_REDUCER; geni=geni+1)
      PatchRowReducer#(.FP_SIZE(FP_SIZE), .N_COL_SIZE(log2(N_COL_MAX))
        , .N_ROW_SIZE(log2(N_ROW_MAX)), .N_PATCH_REDUCER(N_PATCH_REDUCER)
        , .PATCH_REDUCER_INVALID(PATCH_REDUCER_INVALID))
        row_reducer(.dram_clk(dram_clk), .reset(reset)
        , .init(row_init[geni]), .available(row_reducer_avail[geni])
        , .therow(row_reducer_init_row), .thecol(row_reducer_init_col)
        , .theweights(row_reducer_init_weights)
        , .n_row(cl_n_row), .l_col(cl_n_col), .ds_valid_in(dark_sub_rdy[0])
        , .ds0(fdark_subtracted[0]), .ds1(fdark_subtracted[1])
        , .sum(row_sum[geni]), .sum_rdy(row_sum_rdy[geni]));
  endgenerate

  assign dram_rd_coeff_kind = dram_data[(APP_DATA_WIDTH-2)+:2];
  assign pc_msg_coeff_kind = pc_msg[(XB_SIZE-2)+:2];
  assign dram_rd_fifo_pending = ~dram_rd_fifo_empty;
  assign pc_msg_is_dn = pc_msg_pending
    && pc_msg_coeff_kind == COEFF_KIND_INVALID
    && tmp_data_offset == (APP_DATA_WIDTH - XB_SIZE);
  assign {dn[0], fval, lval, dn[1]} = pc_msg[2*DN_SIZE+2-1:0];
  assign app_cmd = {2'b00, bread};
  assign row_reducer_avail_1 = row_reducer_avail - 1'b1;
  assign n_row_reducer_avail = row_reducer_avail & row_reducer_avail_1;
  assign coeff_sink_full =
    pixel_coeff_fifo_full || patch_coeff_fifo_full || !n_row_reducer_avail;
  assign coeff_sink_high =
    pixel_coeff_fifo_high || patch_coeff_fifo_high || n_row_reducer_avail < 2;
  
  always @(posedge dram_clk)
    if(reset) begin
      error <= `FALSE;
      heartbeat <= `FALSE;

  		app_addr <= START_ADDR;
      end_addr <= START_ADDR + ADDR_INC;
      app_en <= `FALSE;
      bread <= `FALSE;
      app_wdf_wren <= `FALSE;
      app_wdf_end <= `TRUE;
      tmp_data_offset <= APP_DATA_WIDTH - XB_SIZE;
      dramifc_state <= DRAMIFC_MSG_WAIT;
      
      capture_state <= CAPTURE_STANDBY;
      coeffrd_state <= COEFFRD_BELOW_HIGH;
      
      pc_msg_ack <= `FALSE;
      fpga_msg_valid <= `FALSE;
      fpga_msg <= 0;

      for(i=0; i < N_PATCH_REDUCER; i=i+1) begin
        patch_init[i] <= `FALSE;
        partial_sum_valid[i] <= 0;
      end
      for(i=0; i < N_ROW_REDUCER; i=i+1) begin
        row_init[i] <= `FALSE;
      end
      new_patch_idx_r <= PATCH_REDUCER_IDX_INVALID;
      new_row_reducer_idx_r <= ROW_REDUCER_IDX_INVALID;
    end else begin // normal operation
      fval_d[0] <= pc_msg_is_dn && fval;
      lval_d[0] <= pc_msg_is_dn && lval;
      for(i=1; i < N_DN2F_LATENCY; i=i+1) begin
        fval_d[i] <= fval_d[i-1];
        lval_d[i] <= lval_d[i-1];
      end

      cl_n_col_d[0] <= cl_n_col;
      cl_n_row_d[0] <= cl_n_row;
      for(i=1; i < N_FSUB_LATENCY; i=i+1) begin
        cl_n_col_d[i] <= cl_n_col_d[i-1];
        cl_n_row_d[i] <= cl_n_row_d[i-1];
      end

      for(i=0; i < N_ROW_REDUCER; i=i+1) begin
        if(owner_reducer[i] != PATCH_REDUCER_INVALID) begin
          partial_sum[owner_reducer[i]] <= row_sum[i];
          partial_sum_valid[owner_reducer[i]] <= row_sum_rdy[i];
        end
      end

      pc_msg_ack <= `FALSE;

      case(coeffrd_state)
        COEFFRD_ERROR: error <= `TRUE;
        default: begin
          if(new_patch_idx_r != PATCH_REDUCER_IDX_INVALID)
            patch_init[new_patch_idx_r] <= `FALSE;//clear init for next reuse

          if(new_patch_valid) begin
            if(!patch_reducer_avail[new_patch_idx]) coeffrd_state <= COEFFRD_ERROR;
            else begin
              new_patch_idx_r <= new_patch_idx; //remember for next clock
              patch_id[new_patch_idx] <= new_patch_id;
              patch_init[new_patch_idx] <= `TRUE;
              new_patch_start_row <= new_patch_top_row;
              coeffrd_state <= coeff_sink_full ? COEFFRD_FULL
                 : (pixel_coeff_fifo_high || patch_coeff_fifo_high)
                   ? COEFFRD_ABOVE_HIGH
                   : COEFFRD_BELOW_HIGH;
            end
          end else begin
            coeffrd_state <= coeff_sink_full ? COEFFRD_FULL
               : (pixel_coeff_fifo_high || patch_coeff_fifo_high)
                 ? COEFFRD_ABOVE_HIGH
                 : COEFFRD_BELOW_HIGH;
          end
          
          if(new_row_reducer_idx_r != ROW_REDUCER_IDX_INVALID)
            row_init[new_row_reducer_idx_r] <= `FALSE;//clear init for next reuse

          if(dram_rd_fifo_pending
             && dram_rd_coeff_kind == COEFF_KIND_ROW_REDUCER) begin
            // Look for the first available row reducer to reuse
            if         (row_reducer_avail[0]) begin
              owner_reducer[0] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 0; row_init[0] <= `TRUE;
            end else if(row_reducer_avail[1]) begin
              owner_reducer[1] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 1; row_init[1] <= `TRUE;
            end else if(row_reducer_avail[2]) begin
              owner_reducer[2] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 2; row_init[2] <= `TRUE;
            end else if(row_reducer_avail[3]) begin
              owner_reducer[3] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 3; row_init[3] <= `TRUE;
            end else if(row_reducer_avail[4]) begin
              owner_reducer[4] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 4; row_init[4] <= `TRUE;
            end else if(row_reducer_avail[5]) begin
              owner_reducer[5] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 5; row_init[5] <= `TRUE;
            end else if(row_reducer_avail[6]) begin
              owner_reducer[6] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 6; row_init[6] <= `TRUE;
            end else if(row_reducer_avail[7]) begin
              owner_reducer[7] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 7; row_init[7] <= `TRUE;
            end else if(row_reducer_avail[8]) begin
              owner_reducer[8] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 8; row_init[8] <= `TRUE;
            end else if(row_reducer_avail[9]) begin
              owner_reducer[9] <= dram_data[0+:log2(N_PATCH_REDUCER)];
              new_row_reducer_idx_r <= 9; row_init[9] <= `TRUE;
            end else coeffrd_state <= COEFFRD_ERROR;
            
            {row_reducer_init_weights, row_reducer_init_col}
              <= dram_data[ROW_REDUCER_CONFIG_SIZE_IN_DRAM-1
                          :log2(N_PATCH_REDUCER)];
            row_reducer_init_row //Ask the owning patch the current row
              <= reducer_current_row[dram_data[0+:log2(N_PATCH_REDUCER)]];
          end
        end
      endcase
    
      case(capture_state)
        CAPTURE_ERROR: error <= `TRUE;
        CAPTURE_STANDBY:
          if(fval_d[N_DN2F_LATENCY-1]) begin
            cl_n_row <= 0;
            cl_n_col <= 0;
            cl_n_frame <= 0;
            capture_state <= CAPTURE_INTRALINE;
          end
        CAPTURE_INTRALINE:
          if(pixel_coeff_fifo_empty) capture_state <= CAPTURE_ERROR;
          else
            if(lval_d[N_DN2F_LATENCY-1]) cl_n_col <= cl_n_col + N_PIXEL_PER_CLOCK;
            else
              if(fval_d[N_DN2F_LATENCY-1]) begin
                cl_n_row <= cl_n_row + 1'b1;
                capture_state <= CAPTURE_INTERLINE;
              end else begin
                cl_n_frame <= cl_n_frame + 1'b1;
                capture_state <= CAPTURE_INTERFRAME;
              end
        CAPTURE_INTERLINE:
          if(lval_d[N_DN2F_LATENCY-1]) begin
            cl_n_col <= 0;
            capture_state <= CAPTURE_INTRALINE;
          end
        CAPTURE_INTERFRAME:
          if(lval_d[N_DN2F_LATENCY-1]) begin
            cl_n_row <= 0;
            cl_n_col <= 0;
            capture_state <= CAPTURE_INTRALINE;
          end
      endcase

      case(dramifc_state)
        DRAMIFC_ERROR: error <= `TRUE; // Note this is a final state
        DRAMIFC_MSG_WAIT:
          if(pc_msg_pending) begin
            tmp_data[tmp_data_offset+:32] <= pc_msg;            
            pc_msg_ack <= `TRUE;

            // Is this the beginning of the pixel data?
            if(pc_msg_coeff_kind == COEFF_KIND_INVALID) begin
              app_addr <= START_ADDR;
              bread <= `FALSE;
              app_en <= `TRUE;
              dramifc_state <= DRAMIFC_READING;
            end
            // Is this the last of the tmp_data I was waiting for?
            else if(tmp_data_offset == 0) begin
              app_en <= `TRUE;
              end_addr <= end_addr + ADDR_INC;
              dramifc_state <= DRAMIFC_WR_WAIT;
            end else tmp_data_offset <= tmp_data_offset - XB_SIZE;
          end
        DRAMIFC_WR_WAIT:
          if(app_rdy && app_wdf_rdy) begin
            app_addr <= app_addr + ADDR_INC; // for next write
            app_en <= `FALSE;
            app_wdf_data <= tmp_data[0+:APP_DATA_WIDTH];
            app_wdf_wren <= `TRUE;
            app_wdf_end <= `FALSE;
            dramifc_state <= DRAMIFC_WR1;
          end
        DRAMIFC_WR1:
          if(app_wdf_rdy) begin
            app_wdf_end <= `TRUE;
            app_wdf_data <= tmp_data[APP_DATA_WIDTH+:APP_DATA_WIDTH];
            dramifc_state <= DRAMIFC_WR2;
          end
        DRAMIFC_WR2: begin
          app_en <= `FALSE;
          app_wdf_wren <= `FALSE;
          tmp_data_offset <= APP_DATA_WIDTH - XB_SIZE;          
          dramifc_state <= app_wdf_rdy ? DRAMIFC_MSG_WAIT : DRAMIFC_ERROR;
        end
        DRAMIFC_READING: begin
          if(dram_rd_fifo_full) begin //invariance assertion
            app_en <= `FALSE;
            dramifc_state <= DRAMIFC_ERROR;
          end else begin
            if(app_rd_data_valid) app_addr <= app_addr + ADDR_INC;
            if(app_addr == end_addr) begin
              app_en <= `FALSE;
              dramifc_state <= DRAMIFC_INTERFRAME;
            end else if(coeffrd_state == COEFFRD_FULL) begin
              app_en <= `FALSE;//Note: the address is already incremented
              dramifc_state <= DRAMIFC_THROTTLED;
            end
          end
        end
        DRAMIFC_THROTTLED:
          if(coeffrd_state == COEFFRD_BELOW_HIGH) begin
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
        DRAMIFC_INTERFRAME:
          if(capture_state == CAPTURE_INTERFRAME) begin
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
      endcase
    end

endmodule
