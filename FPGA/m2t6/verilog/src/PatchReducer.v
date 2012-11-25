module PatchRowReducer
#(parameter N_PATCH=1, PATCH_SIZE=1, N_COL_SIZE=1, N_ROW_SIZE=1, FP_SIZE=1
, N_PIXEL_PER_CLK=1, DELAY=1)
(input RESET, CLK, init, fds_val_in//, sum_ack
, input[log2(N_PATCH)-1:0] conf_patch_num
, output reg[log2(N_PATCH)-1:0] patch_num
, input[N_ROW_SIZE-1:0] cur_row, conf_row
, output reg[N_ROW_SIZE-1:0] matcher_row
, input[N_COL_SIZE-1:0] l_col, conf_col, output reg[N_COL_SIZE-1:0] start_col
, input[FP_SIZE-1:0] conf_sum, fds0, fds1, output reg[FP_SIZE-1:0] sum
, input[(PATCH_SIZE * FP_SIZE)-1:0] conf_weights
, output available, done);
`include "function.v"
  integer i;
  localparam N_FMULT_LATENCY = 8, N_FADD_LATENCY = 8;
  localparam N_STATE = 5
    , CONFIG_WAIT = 3'd0
    , MATCH_WAIT = 3'd1
    , MATCHED = 3'd2
    , SUM_WAIT = 3'd3
    , SUM_RDY = 3'd4;
  reg[log2(N_STATE)-1:0] state;
  wire [N_COL_SIZE-1:0] r_col;
  //reg[N_COL_SIZE-1:0] start_col;
  //reg[N_ROW_SIZE-1:0] matcher_row;
  wire fifo_empty, sum2_valid, running_sum_valid;
  wire[N_PIXEL_PER_CLK-1:0] weighted_fds_valid;
  wire[FP_SIZE-1:0] weighted_fds[N_PIXEL_PER_CLK-1:0], sum2, running_sum;
  reg[FP_SIZE-1:0] weight[PATCH_SIZE-1:0];
  reg[log2(PATCH_SIZE)-1:0] n_ds, n_ds_p1, n_sum;

`ifdef USE_COMBINATIONAL_LOGIC
  wire fromWAITtoMATCHED;
  wire[N_PIXEL_PER_CLK-1:0] fds_val;
  wire[log2(N_PIXEL_PER_CLK):0] n_valid_ds;
  
  //assign r_col = l_col + N_PIXEL_PER_CLK;
  assign fromWAITtoMATCHED = (state == MATCH_WAIT)
    && (cur_row == matcher_row) && fds_val_in && (l_col == start_col);
  //assign fds_valid = fromWAITtoMATCHED || state == MATCHED;
  assign fds_val[0] = (fromWAITtoMATCHED && start_col[0]) || (state == MATCHED);
  assign fds_val[1] = fromWAITtoMATCHED
    || (state == MATCHED && (n_ds < (PATCH_SIZE - `TRUE)));
  assign n_valid_ds = fds_val == 2'b11 ? 2'd2
                   : (fds_val == 2'b00 ? 2'd0
                                       : 2'd1);

  fmult fmult0(.clk(CLK)
    , .operation_nd(fds_val[0]), .a(fds0), .b(weight[n_ds])
    , .result(weighted_fds[0]), .rdy(weighted_fds_valid[0]));
  fmult fmult1(.clk(CLK)
    , .operation_nd(fds_val[1]), .a(fds1), .b(weight[n_ds_p1])
    , .result(weighted_fds[1]), .rdy(weighted_fds_valid[1]));
`else
  reg fromWAITtoMATCHED;
  reg [N_PIXEL_PER_CLK-1:0] fds_val;
  reg [log2(N_PIXEL_PER_CLK):0] n_valid_ds;
  reg [FP_SIZE-1:0] fds[N_PIXEL_PER_CLK-1:0];

  fmult fmult0(.clk(CLK)
    , .operation_nd(fds_val[0]), .a(fds[0]), .b(weight[n_ds])
    , .result(weighted_fds[0]), .rdy(weighted_fds_valid[0]));
  fmult fmult1(.clk(CLK)
    , .operation_nd(fds_val[1]), .a(fds[1]), .b(weight[n_ds_p1])
    , .result(weighted_fds[1]), .rdy(weighted_fds_valid[1]));
`endif
    
  //PatchRowMatcher_fifo fifo(.wr_clk(pixel_clk), .rd_clk(math_clk)
  //  , .din(fds0), .wr_en(fds_valid), .full()
  //  , .rd_en(matched_ds_ack), .empty(fifo_empty), .dout(matched_fds));

  fadd add2(.clk(CLK), .operation_nd(|weighted_fds_valid)
    , .a(weighted_fds_valid[0] ? weighted_fds[0] : {FP_SIZE{`FALSE}})
    , .b(weighted_fds_valid[0] ? weighted_fds[1] : {FP_SIZE{`FALSE}})
    , .result(sum2), .rdy(sum2_valid));

  fadd increment(.clk(CLK), .operation_nd(sum2_valid)
    , .a(sum), .b(sum2), .result(running_sum)
    , .rdy(running_sum_valid));
    
  assign done = state == SUM_RDY;
  assign available = state == CONFIG_WAIT;
  
  always @(posedge CLK)
    if(RESET) begin
      fds[0] <= #DELAY 0; fds[1] <= #DELAY 0;
      fromWAITtoMATCHED <= #DELAY `FALSE;
      fds_val[0] <= #DELAY `FALSE; fds_val[1] <= #DELAY `FALSE;
      n_valid_ds <= #DELAY {(log2(N_PIXEL_PER_CLK)+1){`FALSE}};

      n_ds <= #DELAY 0; n_ds_p1 <= #DELAY 1;
      n_sum <= #DELAY 0;
      for(i=0; i < PATCH_SIZE; i=i+1) weight[i] <= #DELAY {FP_SIZE{`FALSE}};
      state <= #DELAY CONFIG_WAIT;
    end else begin
    
`ifndef USE_COMBINATIONAL_LOGIC
      fds[0] <= #DELAY fds0; fds[1] <= #DELAY fds1;
      fromWAITtoMATCHED <= #DELAY (state == MATCH_WAIT)
        && (cur_row == matcher_row) && fds_val_in && (l_col == start_col);
      fds_val[0] <= #DELAY (state == MATCHED)
        || ((state == MATCH_WAIT) && (cur_row == matcher_row) && fds_val_in
            && (l_col == start_col) && start_col[0]);
      fds_val[1] <= #DELAY (state == MATCHED && (n_ds < (PATCH_SIZE - `TRUE)))
        || ((state == MATCH_WAIT) && (cur_row == matcher_row) && fds_val_in
            && (l_col == start_col) && start_col[0]);
      n_valid_ds <= #DELAY fds_val == 2'b11 ? 2'd2
                        : (fds_val == 2'b00 ? 2'd0
                                            : 2'd1);
`endif

      case(state)
        CONFIG_WAIT:
          if(init) begin
            start_col <= #DELAY conf_col;
            matcher_row <= #DELAY conf_row;
            patch_num <= #DELAY conf_patch_num;
            for(i=0; i < PATCH_SIZE; i=i+1)
              weight[i] <= #DELAY conf_weights[i*FP_SIZE+:FP_SIZE];
            n_sum <= #DELAY 0;
            sum <= #DELAY conf_sum;
            n_ds <= #DELAY 0; n_ds_p1 <= #DELAY 1;
            state <= #DELAY MATCH_WAIT;
          end
        MATCH_WAIT:
          if(fromWAITtoMATCHED) begin
            n_ds <= #DELAY n_valid_ds; n_ds_p1 <= #DELAY n_valid_ds + `TRUE;
            state <= #DELAY MATCHED;
          end
        MATCHED: begin
          if(fds_val_in) begin
            n_ds <= #DELAY n_valid_ds; n_ds_p1 <= #DELAY n_valid_ds + `TRUE;
            if(n_valid_ds >= (PATCH_SIZE - n_ds)) begin
              //RESET to avoid accessing bogus weight
              n_ds <= #DELAY 0; n_ds_p1 <= #DELAY 1;
              state <= #DELAY SUM_WAIT;
            end
          end
        end
        SUM_WAIT:
          if(running_sum_valid) begin
            n_sum <= #DELAY n_sum + `TRUE;
            sum <= #DELAY running_sum;
            if(n_sum == (start_col[0] ? PATCH_SIZE/2 : PATCH_SIZE/2-1))
              state <= #DELAY SUM_RDY;
          end
        SUM_RDY: state <= #DELAY CONFIG_WAIT;
        default: begin
        end
      endcase//state
    end
endmodule
