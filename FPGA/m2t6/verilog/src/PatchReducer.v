module PatchRowReducer
#(parameter N_PATCH=1, PATCH_SIZE=1, N_COL_SIZE=1, N_ROW_SIZE=1, FP_SIZE=1
, N_PIXEL_PER_CLK=1)
(input reset, clk, init, fds_val_in//, sum_ack
, input[log2(N_PATCH)-1:0] conf_num, output reg[log2(N_PATCH)-1:0] num
, input[N_ROW_SIZE-1:0] cur_row, conf_row//, output reg[N_ROW_SIZE-1:0] matcher_row
, input[N_COL_SIZE-1:0] l_col, conf_col//, output reg[N_COL_SIZE-1:0] start_col
, input[FP_SIZE-1:0] conf_sum, fds0, fds1, output reg[FP_SIZE-1:0] sum
, input[(PATCH_SIZE * FP_SIZE)-1:0] conf_weights
, output available, done);
`include "function.v"
  integer i;
  localparam N_FMULT_LATENCY = 8, N_FADD_LATENCY = 8;
  localparam CONFIG_WAIT = 0, MATCH_WAIT = 1, MATCHED = 2, SUM_WAIT = 3
    , SUM_RDY = 4, N_STATE = 5;
  reg[log2(N_STATE)-1:0] state;
  wire [N_COL_SIZE-1:0] r_col;
  reg[N_COL_SIZE-1:0] start_col;
  reg[N_ROW_SIZE-1:0] matcher_row;
  wire fromWAITtoMATCHED, fifo_empty, sum2_valid, running_sum_valid;
  wire[N_PIXEL_PER_CLK-1:0] fds_val, weighted_fds_valid;
  wire[FP_SIZE-1:0] weighted_fds[N_PIXEL_PER_CLK-1:0], sum2, running_sum;
  reg[FP_SIZE-1:0] weight[PATCH_SIZE-1:0];
  reg[log2(PATCH_SIZE)-1:0] n_ds, n_sum;
  wire[log2(N_PIXEL_PER_CLK):0] n_valid_ds;
  
  //assign r_col = l_col + N_PIXEL_PER_CLK;
  assign fromWAITtoMATCHED = (state == MATCH_WAIT)
    && (cur_row == matcher_row) && fds_val_in && (l_col == start_col);
  //assign fds_valid = fromWAITtoMATCHED || state == MATCHED;
  assign fds_val[0] = (fromWAITtoMATCHED && start_col[0]) || (state == MATCHED);
  assign fds_val[1] = fromWAITtoMATCHED
    || (state == MATCHED && (n_ds < (PATCH_SIZE - `TRUE)));
  assign n_valid_ds = fds_val == 2'b11 ? 2'd2 : (fds_val == 2'b00 ? 2'd0 : 2'd1);
    
  //PatchRowMatcher_fifo fifo(.wr_clk(pixel_clk), .rd_clk(math_clk)
  //  , .din(fds0), .wr_en(fds_valid), .full()
  //  , .rd_en(matched_ds_ack), .empty(fifo_empty), .dout(matched_fds));

  fmult fmult0(.clk(clk),
    .operation_nd(fds_val[0]), .a(fds0), .b(weight[n_ds])
    , .result(weighted_fds[0]), .rdy(weighted_fds_valid[0]));
  fmult fmult1(.clk(clk), 
    .operation_nd(fds_val[1]), .a(fds1), .b(weight[n_ds + 1'b1])
    , .result(weighted_fds[1]), .rdy(weighted_fds_valid[1]));

  fadd add2(.clk(clk),
    .operation_nd(|weighted_fds_valid)
    , .a(weighted_fds_valid[0] ? weighted_fds[0] : {FP_SIZE{`FALSE}})
    , .b(weighted_fds_valid[0] ? weighted_fds[1] : {FP_SIZE{`FALSE}})
    , .result(sum2), .rdy(sum2_valid));

  fadd increment(.clk(clk),
    .operation_nd(sum2_valid)
    , .a(sum), .b(sum2), .result(running_sum)
    , .rdy(running_sum_valid));
    
  assign done = state == SUM_RDY;
  assign available = state == CONFIG_WAIT;
  
  always @(posedge reset, posedge clk)
    if(reset) begin
      n_ds <= 0;
      n_sum <= 0;
      state <= CONFIG_WAIT;
    end else begin
      case(state)
        CONFIG_WAIT:
          if(init) begin
            num <= conf_num;
            start_col <= conf_col;
            matcher_row <= conf_row;
            for(i=0; i < PATCH_SIZE; i=i+1)
              weight[i] <= conf_weights[i*FP_SIZE+:FP_SIZE];
            n_sum <= 0;
            sum <= conf_sum;
            n_ds <= 0;
            state <= MATCH_WAIT;
          end
        MATCH_WAIT:
          if(fromWAITtoMATCHED) begin
            n_ds <= n_valid_ds;
            state <= MATCHED;
          end
        MATCHED: begin
          if(fds_val_in) begin
            n_ds <= n_ds + n_valid_ds;
            if(n_valid_ds >= (PATCH_SIZE - n_ds)) begin
              n_ds <= 0;//reset to avoid accessing bogus weight
              state <= SUM_WAIT;
            end
          end
        end
        SUM_WAIT:
          if(running_sum_valid) begin
            n_sum <= n_sum + `TRUE;
            sum <= running_sum;
            if(n_sum == (start_col[0] ? 5 : 4)) //TODO: don't hard code
              state <= SUM_RDY;
          end
        SUM_RDY: state <= CONFIG_WAIT;
        default: begin
        end
      endcase
    end
endmodule
