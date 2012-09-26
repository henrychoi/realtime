module PatchRowReducer#(parameter APP_DATA_WIDTH=256
, PATCH_SIZE=6, N_COL_SIZE=12, PIXEL_SIZE=12, WEIGHT_SIZE=16
, N_PATCH_REDUCER=1, ROW_SUM_SIZE=1)
(// camera link clock domain
input cl_clk, pixel012_valid, pixel3_valid
, input[N_COL_SIZE-1:0] l_col, r_col
, input[47:0] pixel_top, pixel_btm
// dram clock domain
, input reset, dram_clk, init, sum_ack
, input[APP_DATA_WIDTH-1:0] config_data
, output reg[log2(N_PATCH_REDUCER)-1:0] owner_reducer
, output sum_rdy, output reg[ROW_SUM_SIZE-1:0] sum
);
`include "function.v"
  localparam CONFIG_WAIT = 0, DATA_WAIT = 1, SUM_RDY = 2, N_LOGIC_STATE = 3;
  reg[log2(N_LOGIC_STATE)-1:0] state;
  localparam CL_UNINITIALIZED = 0, CL_WAIT = 1, CL_MATCHED = 2, CL_DONE = 3
    , N_CL_STATE = 4;
  reg[log2(N_CL_STATE)-1:0] cl_state;
  reg[log2(PATCH_SIZE)-1:0] cl_pixels_remaining;
  wire[2:0] n_valid_pixels;
  reg matched_pixel_ack
    , cl_bTop, bTop_d    // to cross the clock domain
    , cl_init, cl_init_d;// to cross the clock domain
  reg[N_COL_SIZE-1:0] cl_start_col, start_col_d;
  wire fifo_empty, fifo_wren;
  wire p0_valid, p1_valid, p2_valid, p3_valid;
  wire[1:0] r_minus_start;
  wire fromWAITtoMATCHED;
  wire matched_pixel_pending, matched_pixel_valid;
  wire[PIXEL_SIZE-1:0] matched_pixel;
  
  assign matched_pixel_pending = !fifo_empty;
  assign r_minus_start = r_col - cl_start_col;
  assign fromWAITtoMATCHED = (cl_state == CL_WAIT)
    && (pixel012_valid || pixel3_valid) && (cl_start_col <= r_col);
  assign p0_valid = (cl_state == CL_MATCHED)
    || (fromWAITtoMATCHED
        && ((pixel3_valid && r_minus_start == 3)
            || (!pixel3_valid && r_minus_start == 2)));
  assign p1_valid = (cl_state == CL_MATCHED && cl_pixels_remaining > 1)
    || (fromWAITtoMATCHED
        && ((pixel3_valid && r_minus_start[1]/* r_minus_start > 1 */)
            || (!pixel3_valid && r_minus_start != 0 /* r_minus_start > 0*/)));
  assign p2_valid = (cl_state == CL_MATCHED && cl_pixels_remaining > 2)
    || (fromWAITtoMATCHED
        && !(pixel3_valid && r_minus_start == 0 /* right_col == start_col*/));
  assign p3_valid = pixel3_valid
    && (fromWAITtoMATCHED
        || (cl_state == CL_MATCHED && cl_pixels_remaining >= 4));
  assign n_valid_pixels = p0_valid + p1_valid + p2_valid + p3_valid;
  assign fifo_wren = fromWAITtoMATCHED || cl_state == CL_MATCHED;
    
  always @(posedge reset, posedge cl_clk)
    if(reset) begin
      cl_state <= CL_UNINITIALIZED;
      cl_bTop <= `FALSE;
      cl_init <= `FALSE;
    end else begin
      // Cross from DRAM clock domain to cl clock domain
      cl_init <= cl_init_d;      
      case(cl_state)
        CL_UNINITIALIZED:
          if(cl_init_d) begin
            cl_bTop <= bTop_d;
            cl_start_col <= start_col_d;
            cl_pixels_remaining <= PATCH_SIZE;
            cl_state <= CL_WAIT;
          end
        CL_WAIT:
          if(fromWAITtoMATCHED) begin
            cl_pixels_remaining <= cl_pixels_remaining
              - n_valid_pixels /* r_minus_start + 1 */;
            cl_state <= CL_MATCHED;
          end
        CL_MATCHED: begin
          cl_pixels_remaining <= cl_pixels_remaining - n_valid_pixels;
          if(n_valid_pixels >= cl_pixels_remaining) cl_state <= CL_DONE;
        end
        CL_DONE: if(state == CONFIG_WAIT) cl_state <= CL_UNINITIALIZED;
        default: begin
        end
      endcase
    end

  // FIFO connects the camera clock and dram clock domain
  PatchRowMatcher_fifo fifo(.wr_clk(cl_clk), .rd_clk(dram_clk)
    , .din(cl_bTop
           ? {p0_valid, pixel_top[47:36], p1_valid, pixel_top[35:24]
            , p2_valid, pixel_top[23:12], p3_valid, pixel_top[11:0]}
           : {p0_valid, pixel_btm[47:36], p1_valid, pixel_btm[35:24]
            , p2_valid, pixel_btm[23:12], p3_valid, pixel_btm[11:0]})
    , .wr_en(fifo_wren), .full()
    , .rd_en(matched_pixel_ack), .empty(fifo_empty)
    , .dout({matched_pixel_valid, matched_pixel}));
  
  reg[PIXEL_SIZE-1:0] dark[PATCH_SIZE-1:0];
  reg[WEIGHT_SIZE-1:0] weight[PATCH_SIZE-1:0];
  wire[PIXEL_SIZE+WEIGHT_SIZE:0] weighted_pixel;
  wire[PIXEL_SIZE-1:0] dark_subtracted;
  reg[log2(PATCH_SIZE)-1:0] n_pixel;

  assign dark_subtracted = matched_pixel - dark[n_pixel];
  assign weighted_pixel = dark_subtracted * weight[n_pixel];
  assign sum_rdy = state == SUM_RDY;
  
  always @(posedge reset, posedge dram_clk)
    if(reset) begin
      matched_pixel_ack <= `FALSE;
      n_pixel <= 0;
      state <= CONFIG_WAIT;
    end else begin
      matched_pixel_ack <= matched_pixel_pending;
      case(state)
        CONFIG_WAIT:
          if(init) begin
            {dark[5],weight[5], dark[4],weight[4], dark[3],weight[3]
            , dark[2],weight[2], dark[1],weight[1], dark[0],weight[0]
            , start_col_d, bTop_d
            , owner_reducer
            } <= config_data[(PIXEL_SIZE+WEIGHT_SIZE) * 6 //dark, weight
                             + N_COL_SIZE //start_col_d, bTop_d
                             + log2(N_PATCH_REDUCER) //owner_reducer
                             : 0];
            cl_init_d <= `TRUE;
            sum <= 0;
            n_pixel <= 0;
            state <= DATA_WAIT;
          end
        DATA_WAIT:
          if(matched_pixel_valid) begin
            n_pixel <= n_pixel + 1;
            sum <= sum + weighted_pixel;
            if(n_pixel == (PATCH_SIZE - 1)) begin
              n_pixel <= 0;//reset to avoid accessing bogus weight
              state <= SUM_RDY;
            end
          end
        SUM_RDY:
          if(sum_ack) begin
            state <= CONFIG_WAIT;
          end
        default: begin
        end
      endcase
    end
  
endmodule
