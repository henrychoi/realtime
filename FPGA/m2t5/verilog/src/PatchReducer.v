module PatchRowReducer
#(parameter N_PATCH=1, PATCH_SIZE=1, N_COL_SIZE=1, N_ROW_SIZE=1, FP_SIZE=1
, N_PIXEL_PER_CLK=1)
(input reset, clk, init, fds_val_in//, sum_ack
, input[log2(N_PATCH)-1:0] conf_num, output reg[log2(N_PATCH)-1:0] num
, input[N_ROW_SIZE-1:0] cur_row, conf_row, output reg[N_ROW_SIZE-1:0] matcher_row
, input[N_COL_SIZE-1:0] l_col, conf_col, output reg[N_COL_SIZE-1:0] start_col
, input[FP_SIZE-1:0] conf_sum, fds0, fds1, fds2, fds3
, output reg[FP_SIZE-1:0] sum
, input[(PATCH_SIZE * FP_SIZE)-1:0] conf_weights
, output available, done);
`include "function.v"
  integer i;
  localparam N_FMULT_LATENCY = 8, N_FADD_LATENCY = 8;
  localparam CONFIG_WAIT = 0, MATCH_WAIT = 1, MATCHED = 2, SUM_WAIT = 3
    , SUM_RDY = 4, N_STATE = 5;
  reg[log2(N_STATE)-1:0] state;
  wire [N_COL_SIZE-1:0] r_col;
  //reg[N_COL_SIZE-1:0] start_col;
  //reg[N_ROW_SIZE-1:0] matcher_row;
  wire fromWAITtoMATCHED, fifo_empty
    , sum01_valid, sum23_valid, sum0123_valid, running_sum_valid;
  wire[N_PIXEL_PER_CLK-1:0] fds_val, weighted_fds_valid;
  wire[FP_SIZE-1:0] weighted_fds[N_PIXEL_PER_CLK-1:0]
    , sum01, sum23, sum0123, running_sum;
  reg[FP_SIZE-1:0] weight[PATCH_SIZE-1:0];
  reg[log2(PATCH_SIZE)-1:0] n_ds, n_sum;
  wire[log2(N_PIXEL_PER_CLK):0] n_valid_ds;
  
  assign r_col = l_col + N_PIXEL_PER_CLK;
  assign fromWAITtoMATCHED = fds_val_in && (state == MATCH_WAIT)
    && (cur_row == matcher_row) && (r_col >= start_col);
  assign fds_val[0] = (fromWAITtoMATCHED && !start_col[1:0])
    || (state == MATCHED && n_ds < (PATCH_SIZE - 3'd4));
  assign fds_val[1] = (fromWAITtoMATCHED && !start_col[1])
    || (state == MATCHED && n_ds < (PATCH_SIZE - 3'd3));
  assign fds_val[2] = (fromWAITtoMATCHED && start_col[1:0] == 2'd2)
    || (state == MATCHED && n_ds < (PATCH_SIZE - 3'd2));
  assign fds_val[3] = (fromWAITtoMATCHED && start_col[1:0] == 2'd3)
    || (state == MATCHED && n_ds < (PATCH_SIZE - 3'd1));
    
  assign n_valid_ds = fds_val == 4'b1111 ? 3'd4
    : (fds_val == 4'b0111 || fds_val == 4'b1110) ? 3'd3
    : (fds_val == 4'b0011 || fds_val == 4'b1100) ? 3'd2
    : (fds_val == 4'b0001 || fds_val == 4'b1000) ? 3'd1
    : 3'd0;
    
  //PatchRowMatcher_fifo fifo(.wr_clk(pixel_clk), .rd_clk(math_clk)
  //  , .din(fds0), .wr_en(fds_valid), .full()
  //  , .rd_en(matched_ds_ack), .empty(fifo_empty), .dout(matched_fds));

  fmult fmult0(.clk(clk)
    , .operation_nd(fds_val[0]), .a(fds0), .b(weight[n_ds])
    , .result(weighted_fds[0]), .rdy(weighted_fds_valid[0]));
  fmult fmult1(.clk(clk)
    , .operation_nd(fds_val[1]), .a(fds1), .b(weight[n_ds + 1'd1])
    , .result(weighted_fds[1]), .rdy(weighted_fds_valid[1]));
  fmult fmult2(.clk(clk)
    , .operation_nd(fds_val[2]), .a(fds2), .b(weight[n_ds + 2'd2])
    , .result(weighted_fds[2]), .rdy(weighted_fds_valid[2]));
  fmult fmult3(.clk(clk)
    , .operation_nd(fds_val[3]), .a(fds3), .b(weight[n_ds + 3'd3])
    , .result(weighted_fds[3]), .rdy(weighted_fds_valid[3]));

  fadd add01(.clk(clk), .operation_nd(|weighted_fds_valid[1:0])
    , .a(weighted_fds_valid[0] ? weighted_fds[0] : {FP_SIZE{`FALSE}})
    , .b(weighted_fds_valid[1] ? weighted_fds[1] : {FP_SIZE{`FALSE}})
    , .result(sum01), .rdy(sum01_valid));
  fadd add23(.clk(clk), .operation_nd(|weighted_fds_valid[3:2])
    , .a(weighted_fds_valid[2] ? weighted_fds[2] : {FP_SIZE{`FALSE}})
    , .b(weighted_fds_valid[3] ? weighted_fds[3] : {FP_SIZE{`FALSE}})
    , .result(sum23), .rdy(sum23_valid));
  fadd add0123(.clk(clk), .operation_nd(sum01_valid || sum23_valid)
    , .a(sum01_valid ? sum01 : {FP_SIZE{`FALSE}})
    , .b(sum23_valid ? sum23 : {FP_SIZE{`FALSE}})
    , .result(sum0123), .rdy(sum0123_valid));

  fadd increment(.clk(clk), .operation_nd(sum0123_valid)
    , .a(sum), .b(sum0123), .result(running_sum)
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
            n_ds <= n_valid_ds;
            state <= MATCHED;
          end
        MATCHED: begin
          if(fds_val_in) begin
            n_ds <= n_ds + N_PIXEL_PER_CLK;//n_valid_ds;
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
            if(n_sum == (start_col[1:0] ? PATCH_SIZE/4 : PATCH_SIZE/4-1))
              state <= SUM_RDY;
          end
        SUM_RDY: state <= CONFIG_WAIT;
        default: begin
        end
      endcase
    end
endmodule
