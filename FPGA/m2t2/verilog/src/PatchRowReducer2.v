module PatchRowReducer#(parameter APP_DATA_WIDTH=1
, PATCH_SIZE=1, N_COL_SIZE=1, N_ROW_SIZE=1, FP_SIZE=1
, N_PATCH_REDUCER=1, PATCH_REDUCER_INVALID=1)
(input[N_ROW_SIZE-1:0] n_row, input[N_COL_SIZE-1:0] l_col
, input[FP_SIZE-1:0] ds0, ds1
, input reset, dram_clk, init, ds_valid_in//, sum_ack
, input[APP_DATA_WIDTH-1:0] config_data
, output reg[log2(N_PATCH_REDUCER)-1:0] owner_reducer
, output sum_rdy, output reg[FP_SIZE-1:0] sum
);
`include "function.v"
  integer i;
  localparam CONFIG_WAIT = 0, DATA_WAIT = 1, SUM_WAIT = 2, SUM_RDY = 3
    , N_LOGIC_STATE = 4;
  reg[log2(N_LOGIC_STATE)-1:0] state;
  localparam MATCHER_UNINITIALIZED = 0, MATCHER_WAIT = 1, MATCHER_MATCHED = 2
    , MATCHER_DONE = 3, N_MATCHER_STATE = 4;
  reg[log2(N_MATCHER_STATE)-1:0] matcher_state;
  reg[log2(PATCH_SIZE)-1:0] matcher_ds_remaining;
  wire[1:0] n_valid_ds;
  reg matched_ds_ack;
  reg[N_COL_SIZE-1:0] start_col;
  reg[N_ROW_SIZE-1:0] matcher_row;
  wire fifo_empty;
  wire[1:0] ds_valid;
  wire[1:0] r_minus_start;
  wire fromWAITtoMATCHED;
  wire matched_ds_pending, matched_ds_valid, weighted_ds_valid, running_sum_valid;
  wire[FP_SIZE-1:0] matched_ds, weighted_ds, running_sum;
  wire[N_COL_SIZE-1:0] r_col;
  reg[FP_SIZE-1:0] weight[PATCH_SIZE-1:0];
  reg[log2(PATCH_SIZE)-1:0] n_ds, n_sum;
  
  assign r_col = l_col + 1'b1;
  assign matched_ds_pending = !fifo_empty;
  assign r_minus_start = r_col - start_col;
  assign fromWAITtoMATCHED = (matcher_state == MATCHER_WAIT)
    && (n_row == matcher_row) && ds_valid_in && (start_col <= r_col);
  assign ds_valid[0] = (fromWAITtoMATCHED && start_col[0])
    || (matcher_state == MATCHER_MATCHED);
  assign ds_valid[1] = fromWAITtoMATCHED
    || (matcher_state == MATCHER_MATCHED && matcher_ds_remaining);
  assign n_valid_ds = ds_valid == 2'b11
    ? 2'd2 : (ds_valid == 2'b00 ? 2'd0 : 2'd1);
    
  // FIFO connects the camera clock and dram clock domain
  PatchRowMatcher_fifo fifo(.wr_clk(dram_clk), .rd_clk(dram_clk)
    , .din({ds0_valid, ds0, ds1_valid, ds1})
    , .wr_en(fromWAITtoMATCHED || matcher_state == MATCHER_MATCHED), .full()
    , .rd_en(matched_ds_ack), .empty(fifo_empty)
    , .dout({matched_ds_valid, matched_ds}));
  fmult fmult(.clk(dram_clk)
    , .operation_nd(matched_ds_valid && matched_ds_pending)
    , .a(matched_ds), .b(weight[n_ds]), .result(weighted_ds)
    , .rdy(weighted_ds_valid));
  fadd fadd(.clk(dram_clk), .operation_nd(weighted_ds_valid)
    , .a(sum), .b(weighted_ds), .result(running_sum)
    , .rdy(running_sum_valid));
    
  assign sum_rdy = state == SUM_RDY;
  
  always @(posedge reset, posedge dram_clk)
    if(reset) begin
      matcher_state <= MATCHER_UNINITIALIZED;
      matched_ds_ack <= `FALSE;
      n_ds <= 0;
      n_sum <= 0;
      state <= CONFIG_WAIT;
    end else begin
      case(matcher_state)
        MATCHER_UNINITIALIZED:
          if(init) begin
            start_col <= start_col;
            matcher_ds_remaining <= PATCH_SIZE;
            matcher_state <= MATCHER_WAIT;
          end
        MATCHER_WAIT:
          if(fromWAITtoMATCHED) begin
            matcher_ds_remaining <= matcher_ds_remaining - n_valid_ds;
            matcher_state <= MATCHER_MATCHED;
          end
        MATCHER_MATCHED: begin
          matcher_ds_remaining <= matcher_ds_remaining - n_valid_ds;
          if(n_valid_ds >= matcher_ds_remaining) matcher_state <= MATCHER_DONE;
        end
        MATCHER_DONE:
          if(state == CONFIG_WAIT) matcher_state <= MATCHER_UNINITIALIZED;
        default: begin
        end
      endcase

      matched_ds_ack <= matched_ds_pending;

      case(state)
        CONFIG_WAIT:
          if(init) begin
            matcher_row <= n_row;
            {owner_reducer, start_col}
              <= config_data[0+:log2(N_PATCH_REDUCER) //owner_reducer
                                + N_COL_SIZE]; //start_col
            for(i=0; i < PATCH_SIZE; i=i+1)
              weight[i] <= config_data[(log2(N_PATCH_REDUCER) + N_COL_SIZE
                                       + i*FP_SIZE)+: FP_SIZE];
            n_sum <= 0;
            sum <= 0;
            n_ds <= 0;
            state <= DATA_WAIT;
          end
        DATA_WAIT:
          if(matched_ds_valid) begin
            n_ds <= n_ds + 1'b1;
            if(n_ds == (PATCH_SIZE - 1)) begin
              n_ds <= 0;//reset to avoid accessing bogus weight
              state <= SUM_WAIT;
            end
          end
        SUM_WAIT:
          if(running_sum_valid) begin
            n_sum <= n_sum + 1'b1;
            sum <= running_sum;
            if(n_sum == (PATCH_SIZE - 1)) state <= SUM_RDY;
          end
        SUM_RDY: state <= CONFIG_WAIT;
        default: begin
        end
      endcase
    end
  
endmodule
