module PatchReducer#(parameter PATCH_SIZE=6, ROW_SUM_SIZE=1, PATCH_SUM_SIZE=1)
(input reset, dram_clk, init, sum_ack
, input[ROW_SUM_SIZE-1:0] partial_sum, input[1:0] partial_sum_valid
, output sum_rdy, output reg[PATCH_SUM_SIZE-1:0] sum
);
`include "function.v"
  localparam CONFIG_WAIT = 0, DATA_WAIT = 1, SUM_RDY = 2, N_STATE = 3;
  reg[log2(N_STATE)-1:0] state;
  reg[log2(PATCH_SIZE)-1:0] n_row;

  assign sum_rdy = state == SUM_RDY;
  
  always @(posedge reset, posedge dram_clk)
    if(reset) begin
      n_row <= 0;
      state <= CONFIG_WAIT;
    end else begin
      case(state)
        CONFIG_WAIT:
          if(init) begin
            sum <= 0;
            n_row <= 0;
            state <= DATA_WAIT;
          end
        DATA_WAIT:
          if(partial_sum_valid) begin
            n_row <= n_row + 1;
            sum <= sum + partial_sum_valid;
            if(n_row == (PATCH_SIZE - 1)) begin
              n_row <= 0;//reset to avoid accessing bogus row
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
