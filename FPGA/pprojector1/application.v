module application#(parameter DELAY=1, XB_SIZE=32)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output reg pc_msg_ack
, output reg fpga_msg_valid, output reg [XB_SIZE-1:0] fpga_msg);
`include "function.v"  
  localparam ERROR = 0, INIT = 1, READY = 2, N_STATE = 3;
  reg [log2(N_STATE)-1:0] state;
  
  localparam FP_SIZE = 32;
  reg [FP_SIZE-1:0] frand;
  wire[FP_SIZE-1:0] rand;
  wire taus_valid, taus_error;

  tausworth#(.DELAY(DELAY)) tausworth(.CLK(CLK), .RESET(RESET)
    , .valid(taus_valid), .error(taus_error), .rand(rand));

  assign #DELAY GPIO_LED = {taus_valid, `FALSE, state};

  localparam N = 1024, A = 'h3f800400, C = 'h4234f9a2, B = 'h4234f3fa
           , C1 = 'h42350a9b //45.260358
           , C2 = B          //45.238259
           , HALF = 'h3f000000, MINUS_HALF = 'hbf000000 // 0.5f and -0.5f
           , FADD_LATENCY = 11, FMULT_LATENCY = 6
           , TRANSFORM_LATENCY = 2*FADD_LATENCY + FMULT_LATENCY
           , G_UPDATE_LATENCY = FMULT_LATENCY + FADD_LATENCY - 1;
  wire[2:0] xform_stage_rdy;
  reg pool_valid, addr_fifo_ack;
  reg [FP_SIZE-1:0] G //The Chi-squared correction factor
                  , p_out, q_out, r_out, s_out;//from the pool
  wire[FP_SIZE-1:0] ppq, pmq, rps, rms
                  , p_primex2, q_primex2, r_primex2, s_primex2
                  , p_prime1, q_prime1, r_prime1, s_prime1//1st half result
                  , p_prime2, q_prime2, r_prime2, s_prime2//2nd half result
                  , pxG, qxG, rxG, sxG //Chi-square correction intermediate
                  , p_S, q_S, r_S, s_S //Chi-square corrected result
                  , pxGxC2, G_new;
  reg [log2(N)-1:0] pool_addr, pool_start, pool_stride, pool_mask
                  , p_rd_addr, q_rd_addr, r_rd_addr, s_rd_addr;
  wire[log2(N)-1:0] p_wr_addr, q_wr_addr, r_wr_addr, s_wr_addr;
  wire p_addr_fifo_empty, q_addr_fifo_empty
     , r_addr_fifo_empty, s_addr_fifo_empty
     , S_rdy, pxGxC2_rdy, G_rdy;
  reg [log2(N)-3:0] intrapass_ctr;
  reg [TRANSFORM_LATENCY:0] delayed_2nd_half_flag;

  better_fifo#(.TYPE("POOLADDR"), .WIDTH(log2(N)), .DELAY(DELAY))
  p_addr_fifo(.RESET(RESET), .WR_CLK(CLK), .RD_CLK(CLK)
    , .din(p_rd_addr), .wren(state == READY), .full(), .almost_full()
    , .rden(addr_fifo_ack), .dout(p_wr_addr), .empty(p_addr_fifo_empty));

  better_fifo#(.TYPE("POOLADDR"), .WIDTH(log2(N)), .DELAY(DELAY))
  q_addr_fifo(.RESET(RESET), .WR_CLK(CLK), .RD_CLK(CLK)
    , .din(q_rd_addr), .wren(state == READY), .full(), .almost_full()
    , .rden(addr_fifo_ack), .dout(q_wr_addr), .empty(q_addr_fifo_empty));

  better_fifo#(.TYPE("POOLADDR"), .WIDTH(log2(N)), .DELAY(DELAY))
  r_addr_fifo(.RESET(RESET), .WR_CLK(CLK), .RD_CLK(CLK)
    , .din(r_rd_addr), .wren(state == READY), .full(), .almost_full()
    , .rden(addr_fifo_ack), .dout(r_wr_addr), .empty(r_addr_fifo_empty));

  better_fifo#(.TYPE("POOLADDR"), .WIDTH(log2(N)), .DELAY(DELAY))
  s_addr_fifo(.RESET(RESET), .WR_CLK(CLK), .RD_CLK(CLK)
    , .din(s_rd_addr), .wren(state == READY), .full(), .almost_full()
    , .rden(addr_fifo_ack), .dout(s_wr_addr), .empty(s_addr_fifo_empty));

  // 1st stage
  fadd pplusq(.clk(CLK), .a(p_out), .b(q_out), .operation_nd(pool_valid)
            , .result(ppq), .rdy(xform_stage_rdy[0]));
  fsub pminusq(.clk(CLK), .a(p_out), .b(q_out), .operation_nd(pool_valid)
             , .result(pmq), .rdy());
  fadd rpluss(.clk(CLK), .a(r_out), .b(s_out), .operation_nd(pool_valid)
            , .result(rps), .rdy());
  fsub rminuss(.clk(CLK), .a(r_out), .b(s_out), .operation_nd(pool_valid)
             , .result(rms), .rdy());

  // 2nd stage
  fsub A0_p2(.clk(CLK), .a(pmq), .b(rps), .operation_nd(xform_stage_rdy[0])
           , .result(p_primex2), .rdy(xform_stage_rdy[1]));
  fadd A0_q2(.clk(CLK), .a(pmq), .b(rps), .operation_nd(xform_stage_rdy[0])
           , .result(q_primex2), .rdy());
  fsub A0_r2(.clk(CLK), .a(ppq), .b(rms), .operation_nd(xform_stage_rdy[0])
           , .result(r_primex2), .rdy());
  fadd A0_s2(.clk(CLK), .a(ppq), .b(rms), .operation_nd(xform_stage_rdy[0])
           , .result(s_primex2), .rdy());

  // 3rd stage
  fmult A0_p(.clk(CLK), .a(p_primex2), .b(HALF)
           , .operation_nd(xform_stage_rdy[1])
           , .result(p_prime1), .rdy(xform_stage_rdy[2]));
  fmult A0_q(.clk(CLK), .a(q_primex2), .b(HALF)
           , .operation_nd(xform_stage_rdy[1]), .result(q_prime1), .rdy());
  fmult A0_r(.clk(CLK), .a(r_primex2), .b(HALF)
           , .operation_nd(xform_stage_rdy[1]), .result(r_prime1), .rdy());
  fmult A0_s(.clk(CLK), .a(s_primex2), .b(HALF)
           , .operation_nd(xform_stage_rdy[1]), .result(s_prime1), .rdy());

  fmult A1_p(.clk(CLK), .a(p_primex2), .b(MINUS_HALF)
           , .operation_nd(xform_stage_rdy[1]), .result(p_prime2), .rdy());
  fmult A1_q(.clk(CLK), .a(q_primex2), .b(MINUS_HALF)
           , .operation_nd(xform_stage_rdy[1]), .result(q_prime2), .rdy());
  fmult A1_r(.clk(CLK), .a(r_primex2), .b(MINUS_HALF)
           , .operation_nd(xform_stage_rdy[1]), .result(r_prime2), .rdy());
  fmult A1_s(.clk(CLK), .a(s_primex2), .b(MINUS_HALF)
           , .operation_nd(xform_stage_rdy[1]), .result(s_prime2), .rdy());

  // Chi-squared correction
  fmult SpxG(.clk(CLK), .a(p_out), .b(G), .operation_nd(pool_valid)
           , .result(pxG), .rdy(S_rdy));
  fmult SqxG(.clk(CLK), .a(q_out), .b(G), .operation_nd(pool_valid)
           , .result(qxG), .rdy());
  fmult SrxG(.clk(CLK), .a(r_out), .b(G), .operation_nd(pool_valid)
           , .result(rxG), .rdy());
  fmult SsxG(.clk(CLK), .a(s_out), .b(G), .operation_nd(pool_valid)
           , .result(sxG), .rdy());

  // Chi squared correction factor update
  fmult pxGxC2_module(.clk(CLK), .a(pxG), .b(C2), .operation_nd(S_rdy)
           //, .operation_nd(intrapass_ctr == (8'hFF - G_UPDATE_LATENCY))
           , .result(pxGxC2), .rdy(pxGxC2_rdy));
  fadd PlusC1(.clk(CLK), .a(pxGxC2), .b(C1), .operation_nd(pxGxC2_rdy)
            , .result(G_new), .rdy(G_rdy));

//`define USE_BRAM
`ifdef USE_BRAM
  reg bram_wren;  
  bram pool_pq(
    .clka(CLK), .wea(p_wren), .addra(p_addr), .dina(p_in), .douta(p_out)
  , .clkb(CLK), .web(q_wren), .addrb(q_addr), .dinb(q_in), .doutb(q_out));
  bram pool_rs(
    .clka(CLK), .wea(r_wren), .addra(r_addr), .dina(r_in), .douta(r_out)
  , .clkb(CLK), .web(s_wren), .addrb(s_addr), .dinb(s_in), .doutb(s_out));
`else // USE_REGISTER
  reg [FP_SIZE-1:0] pool[N-1:0]; //Hope this fits within an FPGA
`endif
  
  always @(posedge CLK) begin
    if(RESET) begin
      pool_valid <= #DELAY `FALSE;
      pool_addr <= #DELAY {log2(N){`FALSE}};
      pool_start <= #DELAY {log2(N){`FALSE}};
      pool_stride <= #DELAY {log2(N){`FALSE}};
      pool_mask <= #DELAY {log2(N){`FALSE}};
      
      p_rd_addr <= #DELAY {log2(N){`FALSE}};
      q_rd_addr <= #DELAY {log2(N){`FALSE}};
      r_rd_addr <= #DELAY {log2(N){`FALSE}};
      s_rd_addr <= #DELAY {log2(N){`FALSE}};

      pc_msg_ack <= #DELAY `FALSE;
      fpga_msg_valid <= #DELAY `FALSE;
      fpga_msg <= #DELAY 0;
      
      intrapass_ctr <= #DELAY {(log2(N)-2){`FALSE}};
      addr_fifo_ack <= #DELAY `FALSE;
      G <= #DELAY 'h3f800000; //1.0f
      
      state <= #DELAY INIT;
    end else begin
      pool_valid <= #DELAY state == READY;
      pool_start <= #DELAY rand[22+:10];
      pool_stride <= #DELAY {rand[13+:9], `TRUE};
      pool_mask <= #DELAY rand[3+:10];
      
      pc_msg_ack <= #DELAY `FALSE;
      
      p_rd_addr <= #DELAY (pool_start                             )^pool_mask;
      q_rd_addr <= #DELAY (pool_start                 +pool_stride)^pool_mask;
      r_rd_addr <= #DELAY (pool_start+(pool_stride<<1)            )^pool_mask;
      s_rd_addr <= #DELAY (pool_start+(pool_stride<<1)+pool_stride)^pool_mask;

      p_out <= #DELAY pool[p_rd_addr];
      q_out <= #DELAY pool[q_rd_addr];
      r_out <= #DELAY pool[r_rd_addr];
      s_out <= #DELAY pool[s_rd_addr];
      
      delayed_2nd_half_flag <= #DELAY
        {delayed_2nd_half_flag[0+:(TRANSFORM_LATENCY)]
        , intrapass_ctr[log2(N)-3]};

      addr_fifo_ack <= #DELAY `FALSE;

      if(G_rdy) G <= #DELAY G_new;
      
      case(state)
        INIT: begin
          if(taus_error) state <= #DELAY ERROR;
          else if(pc_msg_valid) begin
            pool[pool_addr] <= #DELAY pc_msg;
            pool_addr <= #DELAY pool_addr + `TRUE;//Advance to the next spot
            pc_msg_ack <= #DELAY `TRUE;
            if(pool_addr == {log2(N){`TRUE}}) begin //the last address
              state <= #DELAY READY;
            end
          end
        end
        
        READY: begin
          intrapass_ctr <= #DELAY intrapass_ctr + `TRUE;

          if(taus_error) state <= #DELAY ERROR;
          else if(xform_stage_rdy[2]) begin
            if(p_addr_fifo_empty) state <= #DELAY ERROR;
            else begin
              addr_fifo_ack <= #DELAY `TRUE;
              if(delayed_2nd_half_flag[TRANSFORM_LATENCY]) begin //2nd half
                pool[p_wr_addr] <= #DELAY p_prime2;
                pool[q_wr_addr] <= #DELAY q_prime2;
                pool[r_wr_addr] <= #DELAY r_prime2;
                pool[s_wr_addr] <= #DELAY s_prime2;
              end else begin //1st half
                pool[p_wr_addr] <= #DELAY p_prime1;
                pool[q_wr_addr] <= #DELAY q_prime1;
                pool[r_wr_addr] <= #DELAY r_prime1;
                pool[s_wr_addr] <= #DELAY s_prime1;
              end
            end
          end
          
        end
        
        default: begin
        end
      endcase
    end
  end
endmodule
