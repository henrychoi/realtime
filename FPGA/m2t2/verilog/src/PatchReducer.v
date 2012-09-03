module PatchReducer#(parameter N_ROW_SIZE=1, PATCH_SIZE=1, FP_SIZE=1)
(input reset, dram_clk, init, sum_ack
, input[N_ROW_SIZE-1:0] start_row
, input[FP_SIZE-1:0] partial_sum, input partial_sum_valid
, output reg[N_ROW_SIZE-1:0] current_row
, output sum_rdy, output reg[FP_SIZE-1:0] sum
);
`include "function.v"
  localparam CONFIG_WAIT = 0, DATA_WAIT = 1, SUM_RDY = 2, N_STATE = 3;
  reg[log2(N_STATE)-1:0] state;
  reg[log2(PATCH_SIZE)-1:0] n_row;
  wire[FP_SIZE-1:0] running_sum;
  wire running_sum_valid;

  fadd fadd(.clk(dram_clk), .operation_nd(partial_sum_valid)
    , .a(sum), .b(partial_sum), .result(running_sum)
    , .rdy(running_sum_valid));

  assign sum_rdy = state == SUM_RDY;
  
  always @(posedge reset, posedge dram_clk)
    if(reset) begin
      sum <= 0;
      n_row <= 0;
      state <= CONFIG_WAIT;
    end else begin
      case(state)
        CONFIG_WAIT:
          if(init) begin
            sum <= 0;
            n_row <= 0;
            current_row <= start_row;
            state <= DATA_WAIT;
          end
        DATA_WAIT: begin
          if(running_sum_valid) begin
            n_row <= n_row + 1'b1;
            sum <= running_sum;
            if(n_row == (PATCH_SIZE - 1)) begin
              state <= SUM_RDY;
            end
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
