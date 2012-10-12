`timescale 1 ns / 1 ps
`define DLY #1

module application#(parameter DATA_WIDTH=1, N_LANE=1)
(input USER_CLK, RESET, TX_DST_RDY_N, HARD_ERR, SOFT_ERR, CHANNEL_UP
  , input[0:N_LANE-1] LANE_UP
  , output[7:0] GPIO_LED
  , input[0:DATA_WIDTH-1] RX_D, input RX_SRC_RDY_N
  , output reg[0:DATA_WIDTH-1] TX_D, output reg TX_SRC_RDY_N);
`include "function.v"
  reg[0:DATA_WIDTH-1] expected_data;
  localparam WAIT = 0, UP = 1, ERROR = 2, N_STATE = 3;
  reg[log2(N_STATE)-1:0] state;
  
  reg[7:0] n_hard_error, n_soft_error;
  reg[27:0] n_clock;
  assign GPIO_LED[7:0] = {|n_hard_error, |n_soft_error, CHANNEL_UP, LANE_UP[0]
    , `FALSE, n_reset, expected_data[0], n_clock[27]};
  reg n_reset;

  always @(posedge USER_CLK) begin
    if(RESET) begin
      n_hard_error <= 0; n_soft_error <= 0;
      n_clock <= 0;
      n_reset <= ~n_reset;
    end else begin
      if(HARD_ERR) n_hard_error <= n_hard_error + `TRUE;
      if(SOFT_ERR) n_soft_error <= n_soft_error + `TRUE;
      n_clock <= n_clock + `TRUE;
    end
  end
    
  always @(posedge USER_CLK)
    if(RESET) begin
      TX_D <= 0;
      expected_data <= 0;
      TX_SRC_RDY_N <= `TRUE;
      state <= WAIT;
    end else begin
      case(state)
        WAIT:
          if(CHANNEL_UP) begin
            TX_SRC_RDY_N <= `FALSE;
            state <= UP;
          end
        UP: begin
          if(!CHANNEL_UP || HARD_ERR) state <= ERROR;
          else begin
            if(!TX_DST_RDY_N) TX_D <= TX_D + `TRUE;
            
            if(!RX_SRC_RDY_N) begin//valid data; compare against expected
              if(RX_D != expected_data) begin
                TX_SRC_RDY_N <= `TRUE;
                state <= ERROR;
              end else begin
                expected_data <= expected_data + `TRUE;
              end
            end
          end
        end
        default: TX_SRC_RDY_N <= `TRUE;
      endcase
    end  
endmodule
