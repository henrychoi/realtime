module PatchRowReducer#(parameter PATCH_SIZE=1, N_COL_SIZE=1, N_ROW_SIZE=1, FP_SIZE=1
, N_PATCH_REDUCER=1, PATCH_REDUCER_INVALID=1)
(input[N_ROW_SIZE-1:0] n_row, therow
, input[N_COL_SIZE-1:0] l_col, thecol
, input[FP_SIZE-1:0] ds
, input reset, dram_clk, init, ds_valid_in//, sum_ack
, input[PATCH_SIZE*FP_SIZE-1:0] theweights
, output available, sum_rdy, output reg[FP_SIZE-1:0] sum);
`include "function.v"
  integer i;
  localparam CONFIG_WAIT = 0, MATCH_WAIT = 1, MATCHED = 2, SUM_WAIT = 3
    , SUM_RDY = 4, N_LOGIC_STATE = 5;
  reg[log2(N_LOGIC_STATE)-1:0] state;
  reg[N_COL_SIZE-1:0] start_col;
  reg[N_ROW_SIZE-1:0] matcher_row;
  wire fromWAITtoMATCHED;
  wire ds_valid, weighted_ds_valid, running_sum_valid;
  wire[FP_SIZE-1:0] weighted_ds, running_sum;
  reg[FP_SIZE-1:0] weight[PATCH_SIZE-1:0];
  reg[log2(PATCH_SIZE)-1:0] n_ds, n_sum;
  
  assign fromWAITtoMATCHED = (state == MATCH_WAIT)
    && (n_row == matcher_row) && ds_valid_in && (start_col == l_col);
  assign ds_valid = fromWAITtoMATCHED || state == MATCHED;

  fmult fmult(.clk(dram_clk)
    , .operation_nd(ds_valid), .a(ds), .b(weight[n_ds])
    , .result(weighted_ds), .rdy(weighted_ds_valid));
  fadd fadd(.clk(dram_clk), .operation_nd(weighted_ds_valid)
    , .a(sum), .b(weighted_ds), .result(running_sum)
    , .rdy(running_sum_valid));
    
  assign sum_rdy = state == SUM_RDY;
  assign available = state == CONFIG_WAIT;
  
  always @(posedge reset, posedge dram_clk)
    if(reset) begin
      n_ds <= 0;
      n_sum <= 0;
      state <= CONFIG_WAIT;
    end else begin
      case(state)
        CONFIG_WAIT:
          if(init) begin
            start_col <= thecol;
            matcher_row <= therow;
            for(i=0; i < PATCH_SIZE; i=i+1)
              weight[i] <= theweights[i*FP_SIZE+:FP_SIZE];
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
          if(ds_valid_in) begin
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
