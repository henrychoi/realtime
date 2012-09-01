module PatchRowReducer#(parameter APP_DATA_WIDTH=256
, PATCH_SIZE=6, N_COL_SIZE=12
, N_PATCH_REDUCER=1, PATCH_REDUCER_INVALID = 1, FP_SIZE=1)
(input[N_COL_SIZE-1:0] l_col//, r_col
, input[FP_SIZE-1:0] e_top, e_btm
, input reset, dram_clk
, input[1:0] init, input[APP_DATA_WIDTH-1:0] config_data
, output reg[log2(N_PATCH_REDUCER)-1:0] owner_reducer
, output[1:0] sum_rdy, output reg[FP_SIZE-1:0] sum
);
`include "function.v"
  localparam CONFIG_WAIT = 0, DATA_WAIT = 1, SUM_RDY = 2, N_LOGIC_STATE = 3;
  reg[log2(N_LOGIC_STATE)-1:0] state;
  localparam CL_UNINITIALIZED = 0, CL_WAIT = 1, CL_MATCHED = 2, CL_DONE = 3
    , N_CL_STATE = 4;
  reg[log2(N_CL_STATE)-1:0] cl_state;
  reg[log2(PATCH_SIZE)-1:0] cl_col_remain;
  reg matched_ack
    , cl_init;// to cross the clock domain
  reg[N_COL_SIZE-1:0] cl_start_col;
  wire fifo_empty, fifo_wren;
  wire[1:0] r_minus_start;
  wire fromWAITtoMATCHED;
  wire matched_pending;
  wire[FP_SIZE-1:0] matched_top, matched_btm, weighted_top, weighted_btm;
  reg[FP_SIZE-1:0] weight_top[PATCH_SIZE-1:0], weight_btm[PATCH_SIZE-1:0];
  
  assign matched_pending = !fifo_empty;
  assign fromWAITtoMATCHED = (cl_state == CL_WAIT) && (cl_start_col == l_col);
  assign fifo_wren = fromWAITtoMATCHED || cl_state == CL_MATCHED;
    
  // FIFO connects the camera clock and dram clock domain

  reg[log2(PATCH_SIZE)-1:0] n_col;
  wire do_top, do_btm;
  reg[1:0] topbtm;
  wire matched_valid;

  assign {do_top, do_btm} = topbtm;
  assign weighted_top = do_top ? matched_top * weight_top[n_col] : 0;
  assign weighted_btm = do_btm ? matched_btm * weight_btm[n_col] : 0;
  assign sum_rdy = state == SUM_RDY ? (topbtm == 2'b11 ? 2'd2 : 2'd1) : 2'd0;
  
  always @(posedge reset, posedge dram_clk)
    if(reset) begin
      cl_state <= CL_UNINITIALIZED;

      owner_reducer <= PATCH_REDUCER_INVALID;
      matched_ack <= `FALSE;
      n_col <= 0;
      topbtm <= 0;
      state <= CONFIG_WAIT;
    end else begin
      case(cl_state)
        CL_UNINITIALIZED:
          if(cl_init) begin
            //cl_start_col <= cl_start_col;
            cl_col_remain <= PATCH_SIZE;
            cl_state <= CL_WAIT;
          end
        CL_WAIT:
          if(fromWAITtoMATCHED) begin
            cl_col_remain <= cl_col_remain - 1'b1;
            cl_state <= CL_MATCHED;
          end
        CL_MATCHED: begin
          cl_col_remain <= cl_col_remain - 1'b1;
          if(cl_col_remain == 1) cl_state <= CL_DONE;
        end
        CL_DONE: if(state == CONFIG_WAIT) cl_state <= CL_UNINITIALIZED;
        default: begin
        end
      endcase

      matched_ack <= matched_pending;
      case(state)
        CONFIG_WAIT:
          if(init) begin
            topbtm <= init;
            {weight_top[5], weight_top[4], weight_top[3]
            , weight_top[2], weight_top[1], weight_top[0]
            , cl_start_col, owner_reducer
            } <= config_data[FP_SIZE * PATCH_SIZE//
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
