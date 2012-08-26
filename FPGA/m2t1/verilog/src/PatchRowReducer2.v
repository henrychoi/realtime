module PatchRowReducer#(parameter APP_DATA_WIDTH=256
, PATCH_SIZE=6, N_COL_SIZE=12, e_SIZE=12, WEIGHT_SIZE=16
, N_PATCH_REDUCER=1, PATCH_REDUCER_INVALID = 1, ROW_SUM_SIZE=1)
(// camera link clock domain
input cl_clk, e012_valid, e3_valid
, input[N_COL_SIZE-1:0] l_col, r_col
, input[e_SIZE-1:0] e_top0, e_top1, e_top2, e_top3
                  , e_btm0, e_btm1, e_btm2, e_btm3
// dram clock domain
, input reset, dram_clk
, input[1:0] init, input[APP_DATA_WIDTH-1:0] config_data
, output reg[log2(N_PATCH_REDUCER)-1:0] owner_reducer
, output[1:0] sum_rdy, output reg[ROW_SUM_SIZE-1:0] sum
);
`include "function.v"
  localparam CONFIG_WAIT = 0, DATA_WAIT = 1, SUM_RDY = 2, N_LOGIC_STATE = 3;
  reg[log2(N_LOGIC_STATE)-1:0] state;
  localparam CL_UNINITIALIZED = 0, CL_WAIT = 1, CL_MATCHED = 2, CL_DONE = 3
    , N_CL_STATE = 4;
  reg[log2(N_CL_STATE)-1:0] cl_state;
  reg[log2(PATCH_SIZE)-1:0] cl_col_remain;
  wire[2:0] n_valid_col;
  reg matched_ack
    , cl_init;// to cross the clock domain
  reg[N_COL_SIZE-1:0] cl_start_col;
  wire fifo_empty, fifo_wren;
  wire p0_valid, p1_valid, p2_valid, p3_valid;
  wire[1:0] r_minus_start;
  wire fromWAITtoMATCHED;
  wire matched_pending, matched_valid;
  wire[e_SIZE-1:0] matched_top, matched_btm;
  
  assign matched_pending = !fifo_empty;
  assign r_minus_start = r_col - cl_start_col;
  assign fromWAITtoMATCHED = (cl_state == CL_WAIT)
    && (e012_valid || e3_valid) && (cl_start_col <= r_col);
  assign p0_valid = (cl_state == CL_MATCHED)
    || (fromWAITtoMATCHED
        && ((e3_valid && r_minus_start == 3)
            || (!e3_valid && r_minus_start == 2)));
  assign p1_valid = (cl_state == CL_MATCHED && cl_col_remain > 1)
    || (fromWAITtoMATCHED
        && ((e3_valid && r_minus_start[1]/* r_minus_start > 1 */)
            || (!e3_valid && r_minus_start != 0 /* r_minus_start > 0*/)));
  assign p2_valid = (cl_state == CL_MATCHED && cl_col_remain > 2)
    || (fromWAITtoMATCHED
        && !(e3_valid && r_minus_start == 0 /* right_col == start_col*/));
  assign p3_valid = e3_valid
    && (fromWAITtoMATCHED
        || (cl_state == CL_MATCHED && cl_col_remain >= 4));
  assign n_valid_col = p0_valid + p1_valid + p2_valid + p3_valid;
  assign fifo_wren = fromWAITtoMATCHED || cl_state == CL_MATCHED;
    
  always @(posedge reset, posedge cl_clk)
    if(reset) begin
      cl_state <= CL_UNINITIALIZED;
      //cl_init <= `FALSE;
    end else begin
      // Cross from DRAM clock domain to cl clock domain
      //cl_init <= init_d;
      case(cl_state)
        CL_UNINITIALIZED:
          if(cl_init) begin
            //cl_start_col <= cl_start_col;
            cl_col_remain <= PATCH_SIZE;
            cl_state <= CL_WAIT;
          end
        CL_WAIT:
          if(fromWAITtoMATCHED) begin
            cl_col_remain <= cl_col_remain
              - n_valid_col /* r_minus_start + 1 */;
            cl_state <= CL_MATCHED;
          end
        CL_MATCHED: begin
          cl_col_remain <= cl_col_remain - n_valid_col;
          if(n_valid_col >= cl_col_remain) cl_state <= CL_DONE;
        end
        CL_DONE: if(state == CONFIG_WAIT) cl_state <= CL_UNINITIALIZED;
        default: begin
        end
      endcase
    end

  // FIFO connects the camera clock and dram clock domain
  PatchRowMatcher_fifo fifo(.wr_clk(cl_clk), .rd_clk(dram_clk)
    , .din({p0_valid, e_top0, e_btm0 // asymmetric FIFO shows the data in
          , p1_valid, e_top1, e_btm1 // this order, with granularity of
          , p2_valid, e_top2, e_btm2 // output data width
          , p3_valid, e_top3, e_btm3})
    , .wr_en(fifo_wren), .full()
    , .rd_en(matched_ack), .empty(fifo_empty)
    , .dout({matched_valid, matched_top, matched_btm}));

  reg[WEIGHT_SIZE-1:0] weight_top[PATCH_SIZE-1:0], weight_btm[PATCH_SIZE-1:0];
  wire[e_SIZE+WEIGHT_SIZE:0] weighted_top, weighted_btm;
  reg[log2(PATCH_SIZE)-1:0] n_col;
  wire do_top, do_btm;
  reg[1:0] topbtm;

  assign {do_top, do_btm} = topbtm;
  assign weighted_top = do_top ? matched_top * weight_top[n_col] : 0;
  assign weighted_btm = do_btm ? matched_btm * weight_btm[n_col] : 0;
  assign sum_rdy = state == SUM_RDY ? (topbtm == 2'b11 ? 2'd2 : 2'd1) : 2'd0;
  
  always @(posedge reset, posedge dram_clk)
    if(reset) begin
      owner_reducer <= PATCH_REDUCER_INVALID;
      matched_ack <= `FALSE;
      n_col <= 0;
      topbtm <= 0;
      state <= CONFIG_WAIT;
    end else begin
      matched_ack <= matched_pending;
      case(state)
        CONFIG_WAIT:
          if(init) begin
            topbtm <= init;
            {weight_top[5], weight_top[4], weight_top[3]
            , weight_top[2], weight_top[1], weight_top[0]
            , weight_btm[5], weight_btm[4], weight_btm[3]
            , weight_btm[2], weight_btm[1], weight_btm[0]
            , cl_start_col, owner_reducer
            } <= config_data[WEIGHT_SIZE * PATCH_SIZE * 2//top and bottom
                             + N_COL_SIZE //cl_start_col
                             + log2(N_PATCH_REDUCER) //owner_reducer
                             - 1 : 0];
            cl_init <= `TRUE;
            sum <= 0;
            n_col <= 0;
            state <= DATA_WAIT;
          end
        DATA_WAIT:
          if(matched_valid) begin
            sum <= sum + weighted_top + weighted_btm;
            if(n_col == (PATCH_SIZE - 1)) begin
              //n_col <= 0;//reset to avoid accessing bogus weight
              //topbtm <= 0; //turn off weight calculation
              state <= SUM_RDY;
            end else begin
              n_col <= n_col + 1;
            end
          end
        SUM_RDY: begin
          n_col <= 0;
          topbtm <= 0;
          owner_reducer <= PATCH_REDUCER_INVALID;
          state <= CONFIG_WAIT;
        end
        default: begin
        end
      endcase
    end
endmodule
