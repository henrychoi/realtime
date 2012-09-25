module PatchRowReducer
#(parameter N_PATCH=1, PATCH_SIZE=1, N_COL_SIZE=1, N_ROW_SIZE=1, FP_SIZE=1)
(input[log2(N_PATCH)-1:0] conf_num, output reg[log2(N_PATCH)-1:0] num
, input[N_ROW_SIZE-1:0] cur_row, conf_row, output reg[N_ROW_SIZE-1:0] matcher_row
, input[N_COL_SIZE-1:0] l_col, conf_col, output reg[N_COL_SIZE-1:0] start_col
, input[FP_SIZE-1:0] conf_sum, fds, output reg[FP_SIZE-1:0] sum
, input reset, clk, init, fds_val_in//, sum_ack
, input[(PATCH_SIZE * FP_SIZE)-1:0] conf_weights
, output available, done);
`include "function.v"
  integer i;
  localparam N_FMULT_LATENCY = 8, N_FADD_LATENCY = 8;
  localparam CONFIG_WAIT = 0, MATCH_WAIT = 1, MATCHED = 2, SUM_WAIT = 3
    , SUM_RDY = 4, N_STATE = 5;
  reg[log2(N_STATE)-1:0] state;
  //reg[N_COL_SIZE-1:0] start_col;
  //reg[N_ROW_SIZE-1:0] matcher_row;
  wire fromWAITtoMATCHED;
  wire fds_valid, weighted_ds_valid, running_sum_valid;
  wire[FP_SIZE-1:0] weighted_ds, running_sum;
  reg[FP_SIZE-1:0] weight[PATCH_SIZE-1:0];
  reg[log2(PATCH_SIZE)-1:0] n_ds, n_sum;
  
  assign fromWAITtoMATCHED = (state == MATCH_WAIT)
    && (cur_row == matcher_row) && fds_val_in && (l_col == start_col);
  assign fds_valid = fromWAITtoMATCHED || state == MATCHED;

  fmult fmult(.clk(clk)
    , .operation_nd(fds_valid), .a(fds), .b(weight[n_ds])
    , .result(weighted_ds), .rdy(weighted_ds_valid));
  fadd fadd(.clk(clk), .operation_nd(weighted_ds_valid)
    , .a(sum), .b(weighted_ds), .result(running_sum)
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
            start_col <= conf_col;
            matcher_row <= conf_row;
            for(i=0; i < PATCH_SIZE; i=i+1)
              weight[i] <= conf_weights[i*FP_SIZE+:FP_SIZE];
            n_sum <= 0;
            sum <= 0;
            n_ds <= 0;
            state <= MATCH_WAIT;
          end
        MATCH_WAIT:
          if(fromWAITtoMATCHED) begin
            n_ds <= 1;
            state <= MATCHED;
          end
        MATCHED: begin
          if(fds_val_in) begin
            n_ds <= n_ds + 1'b1;
            if(n_ds == (PATCH_SIZE - 1)) begin
              n_ds <= 0;//reset to avoid accessing bogus weight
              state <= SUM_WAIT;
            end
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
