module PatchRowMatcher#(parameter PATCH_SIZE=6, N_COL_SIZE=12)
(input cl_clk, reset
, init_en, bTop_in
, start_col_b00, start_col_b01, start_col_b02, start_col_b03
, start_col_b04, start_col_b05, start_col_b06, start_col_b07
, start_col_b08, start_col_b09, start_col_b10, start_col_b11
, input[N_COL_SIZE-1:0] l_col, r_col
, input pixel012_valid, pixel3_valid
, input[47:0] pixel_top, pixel_btm
, input rd_clk, input pixel_ack
, output somepixel_pending, matched_pixel_valid
  , matched_pixel_b00, matched_pixel_b01, matched_pixel_b02
  , matched_pixel_b03, matched_pixel_b04, matched_pixel_b05
  , matched_pixel_b06, matched_pixel_b07, matched_pixel_b08
  , matched_pixel_b09, matched_pixel_b10, matched_pixel_b11);
`include "function.v"
  localparam UNUSED = 0, WAIT = 1, SENDING = 2, N_STATE = 3;
  reg[log2(N_STATE)-1:0] state;
  reg[log2(PATCH_SIZE)-1:0] pixels_remaining;
  wire[2:0] n_valid_pixels;
  reg bTop;
  reg[N_COL_SIZE-1:0] start_col;
  wire fifo_empty, fifo_wren;
  wire p0_valid, p1_valid, p2_valid, p3_valid;
  wire[1:0] r_minus_start;
  wire fromWAITtoSENDING;

  PatchRowMatcher_fifo fifo(.wr_clk(cl_clk), .rd_clk(rd_clk)
    , .din(bTop
           ? {p0_valid, pixel_top[47:36], p1_valid, pixel_top[35:24]
            , p2_valid, pixel_top[23:12], p3_valid, pixel_top[11:0]}
           : {p0_valid, pixel_btm[47:36], p1_valid, pixel_btm[35:24]
            , p2_valid, pixel_btm[23:12], p3_valid, pixel_btm[11:0]})
    , .wr_en(fifo_wren), .full()
    , .rd_en(pixel_ack)
    , .dout({matched_pixel_valid
      , matched_pixel_b11, matched_pixel_b10, matched_pixel_b09
      , matched_pixel_b08, matched_pixel_b07, matched_pixel_b06
      , matched_pixel_b05, matched_pixel_b04, matched_pixel_b03
      , matched_pixel_b02, matched_pixel_b01, matched_pixel_b00})
     , .empty(fifo_empty));
  
  assign somepixel_pending = !fifo_empty;
  assign r_minus_start = r_col - start_col;
  assign fromWAITtoSENDING = (state == WAIT)
    && (pixel012_valid || pixel3_valid) && (start_col <= r_col);
  assign p0_valid = (state == SENDING)
    || (fromWAITtoSENDING
        && ((pixel3_valid && r_minus_start == 3)
            || (!pixel3_valid && r_minus_start == 2)));
  assign p1_valid = (state == SENDING && pixels_remaining > 1)
    || (fromWAITtoSENDING
        && ((pixel3_valid && r_minus_start[1]/* r_minus_start > 1 */)
            || (!pixel3_valid && r_minus_start != 0 /* r_minus_start > 0*/)));
  assign p2_valid = (state == SENDING && pixels_remaining > 2)
    || (fromWAITtoSENDING
        && !(pixel3_valid && r_minus_start == 0 /* right_col == start_col*/));
  assign p3_valid = pixel3_valid
    && (fromWAITtoSENDING || (state == SENDING && pixels_remaining >= 4));
  assign n_valid_pixels = p0_valid + p1_valid + p2_valid + p3_valid;
  assign fifo_wren = fromWAITtoSENDING || state == SENDING;
  
  always @(posedge reset, posedge cl_clk)
    if(reset) begin
      state <= UNUSED;
      bTop <= `FALSE;
    end else begin
      case(state)
        UNUSED:
          if(init_en) begin
            bTop <= bTop_in;
            start_col <= {start_col_b11, start_col_b10, start_col_b09
              , start_col_b08, start_col_b07, start_col_b06
              , start_col_b05, start_col_b04, start_col_b03
              , start_col_b02, start_col_b01, start_col_b00};
            pixels_remaining <= PATCH_SIZE;
            state <= WAIT;
          end
        WAIT:
          if(fromWAITtoSENDING) begin
            pixels_remaining <= pixels_remaining
              - n_valid_pixels /* r_minus_start + 1 */;
            state <= SENDING;
          end
        SENDING: begin
          pixels_remaining <= pixels_remaining - n_valid_pixels;
          if(n_valid_pixels >= pixels_remaining) state <= UNUSED;
        end
        default: begin
        end
      endcase
    end
endmodule
