module PatchRowMatcher#(parameter PATCH_SIZE=6, N_COL_SIZE=12)
(input cl_clk, reset
, init_en, bTop_in, input[N_COL_SIZE-1:0] start_col_in, l_col, r_col
, input pixel012_valid, pixel3_valid
, input[11:0] pixel_top[3:0], pixel_btm[3:0]
, output rd_clk, pixel_pending, output[11:0] pixel, input pixel_ack);
`include "function.v"
  localparam UNUSED = 0, WAIT = 1, SENDING = 2, N_STATE = 3;
  reg[log2(N_STATE)-1:0] state;
  reg[log2(PATCH_SIZE)-1:0] pixels_remaining;
  reg bTop;
  reg[N_COL_SIZE-1:0] start_col;
  wire pixel_empty;
  wire[3:0] pixel_valid;
  wire[1:0] r_minus_start;
  
  PatchRowMatcher_fifo fifo(.wr_clk(cl_clk), .rd_clk(rd_clk)
    , .din(bTop
           ? {pixel_valid[0], pixel_top[0], pixel_valid[1], pixel_top[1]
            , pixel_valid[2], pixel_top[2], pixel_valid[3], pixel_top[3]}
           : {pixel_valid[0], pixel_btm[0], pixel_valid[1], pixel_btm[1]
            , pixel_valid[2], pixel_btm[2], pixel_valid[3], pixel_btm[3]})
    , .wr_en(), .full()
    , .rd_en(pixel_ack), .dout(pixel), .empty(pixel_empty));
  
  assign pixel_pending = !pixel_empty;
  assign r_minus_start = r_col - start_col;
  
  always @(posedge reset, posedge clk)
    if(reset) begin
      state <= UNUSED;
      bTop <= `FALSE;
    end else begin
      case(state)
        UNUSED:
          if(init_en) begin
            bTop <= bTop_in;
            start_col <= start_col_in;
            pixels_remaining <= PATCH_SIZE;
            state <= WAIT;
          end
        WAIT:
          if(start_col <= r_col) begin    
            state <= SENDING;
          end
        SENDING: begin
        end
        default: begin
        end
      endcase
    end
endmodule
