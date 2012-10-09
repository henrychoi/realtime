`timescale 1 ns / 1 ps
`define DLY #1

module application#(parameter DATA_WIDTH=1)
(input USER_CLK, RESET, CHANNEL_UP, output HB
  , input[0:DATA_WIDTH-1] RX_D, input RX_SRC_RDY_N
  , output reg[0:DATA_WIDTH-1] TX_D, output reg TX_SRC_RDY_N
  , input TX_DST_RDY_N);
`include "function.v"
  reg[DATA_WIDTH-1:0] expected_data;
  localparam WAIT = 0, UP = 1, ERROR = 2, N_STATE = 3;
  reg[log2(N_STATE)-1:0] state;
  
  assign HB = expected_data[4];
  
  //Generate RESET signal when Aurora channel is not ready
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
          if(!CHANNEL_UP) state <= ERROR;
          else begin
            if(!TX_DST_RDY_N) TX_D <= TX_D + `TRUE;
            
            if(!RX_SRC_RDY_N) begin//valid data; compare against expected
              if(TX_D != expected_data) begin
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
