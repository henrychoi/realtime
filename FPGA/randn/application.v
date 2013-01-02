module application#(parameter DELAY=1, XB_SIZE=32)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output reg pc_msg_ack
, output reg fpga_msg_valid, output reg [XB_SIZE-1:0] fpga_msg);
`include "function.v"  
  localparam INIT = 0, READY = 1, N_STATE = 2;
  reg [log2(N_STATE)-1:0] state;
  
  localparam FP_SIZE = 32;
  reg [FP_SIZE-1:0] frand;
  wire[FP_SIZE-1:0] rand;
  wire valid, error;

  tausworth#(.DELAY(DELAY)) tausworth(.CLK(CLK), .RESET(RESET)
    , .valid(valid), .error(error), .rand(rand));

  assign #DELAY GPIO_LED = {error, valid, `FALSE, state};

  localparam N = 1024, A = 'h3f800400, C = 'h4234f9a2, B = 'h4234f3fa
           , C1 = 'h42350a9b, C2 = B
           , HALF = 'h3f000000, MINUS_HALF = 'hbf000000
           , FADD_LATENCY = 11, FMULT_LATENCY = 6
           , TRANSFORM_LATENCY = 2*FADD_LATENCY + FMULT_LATENCY;
  wire stage1_rdy, stage2_rdy, stage3_rdy;
  wire[FP_SIZE-1:0] p_out, q_out, r_out, s_out//from the pool
                  , ppq, pmq, rps, rms
                  , p_primex2, q_primex2, r_primex2, s_primex2
                  , p_prime1, q_prime1, r_prime1, s_prime1
                  , p_prime2, q_prime2, r_prime2, s_prime2;
  reg [log2(N)-1:0] pool_start, pool_stride, pool_mask
                  , p_wr_addr, q_wr_addr, r_wr_addr, s_wr_addr
                  , p_rd_addr, q_rd_addr, r_rd_addr, s_rd_addr;
  reg [log2(N)-3:0] intrapass_ctr;
  reg [TRANSFORM_LATENCY-1:0] delayed_2nd_half_flag;

  // 1st stage
  fadd pplusq(.clk(CLK), .a(p_out), .b(q_out), .operation_nd(state == READY)
            , .result(ppq), .rdy(stage1_rdy));
  fsub pminusq(.clk(CLK), .a(p_out), .b(q_out), .operation_nd(state == READY)
             , .result(pmq), .rdy());
  fadd rpluss(.clk(CLK), .a(r_out), .b(s_out), .operation_nd(state == READY)
            , .result(rps), .rdy());
  fsub rminuss(.clk(CLK), .a(r_out), .b(s_out), .operation_nd(state == READY)
             , .result(rms), .rdy());

  // 2nd stage
  fsub A0_p2(.clk(CLK), .a(pmq), .b(rps), .operation_nd(stage1_rdy)
           , .result(p_primex2), .rdy(stage2_rdy));
  fadd A0_q2(.clk(CLK), .a(pmq), .b(rps), .operation_nd(stage1_rdy)
           , .result(q_primex2), .rdy());
  fsub A0_r2(.clk(CLK), .a(ppq), .b(rms), .operation_nd(stage1_rdy)
           , .result(r_primex2), .rdy());
  fadd A0_s2(.clk(CLK), .a(ppq), .b(rms), .operation_nd(stage1_rdy)
           , .result(s_primex2), .rdy());

  // 3rd stage
  fmult A0_p(.clk(CLK), .a(p_primex2), .b(HALF)
           , .operation_nd(stage2_rdy), .result(p_prime1), .rdy(stage3_rdy));
  fmult A0_q(.clk(CLK), .a(q_primex2), .b(HALF)
           , .operation_nd(stage2_rdy), .result(q_prime1), .rdy());
  fmult A0_r(.clk(CLK), .a(r_primex2), .b(HALF)
           , .operation_nd(stage2_rdy), .result(r_prime1), .rdy());
  fmult A0_s(.clk(CLK), .a(s_primex2), .b(HALF)
           , .operation_nd(stage2_rdy), .result(s_prime1), .rdy());

  fmult A1_p(.clk(CLK), .a(p_primex2), .b(MINUS_HALF)
           , .operation_nd(stage2_rdy), .result(p_prime2), .rdy());
  fmult A1_q(.clk(CLK), .a(q_primex2), .b(MINUS_HALF)
           , .operation_nd(stage2_rdy), .result(q_prime2), .rdy());
  fmult A1_r(.clk(CLK), .a(r_primex2), .b(MINUS_HALF)
           , .operation_nd(stage2_rdy), .result(r_prime2), .rdy());
  fmult A1_s(.clk(CLK), .a(s_primex2), .b(MINUS_HALF)
           , .operation_nd(stage2_rdy), .result(s_prime2), .rdy());



//`define USE_BRAM
`ifdef USE_BRAM
  reg [FP_SIZE-1:0] p_in, q_in, r_in, s_in;
  reg bram_wren;
  
  bram pool_pq(
    .clka(CLK), .wea(p_wren), .addra(p_addr), .dina(p_in), .douta(p_out)
  , .clkb(CLK), .web(q_wren), .addrb(q_addr), .dinb(q_in), .doutb(q_out));
  bram pool_rs(
    .clka(CLK), .wea(r_wren), .addra(r_addr), .dina(r_in), .douta(r_out)
  , .clkb(CLK), .web(s_wren), .addrb(s_addr), .dinb(s_in), .doutb(s_out));

`else // USE_REGISTER
  reg [FP_SIZE-1:0] pool[N-1:0]; //Hope this fits within an FPGA
  assign p_out = pool[p_rd_addr];
  assign q_out = pool[q_rd_addr];
  assign r_out = pool[r_rd_addr];
  assign s_out = pool[s_rd_addr];
  
  always @(posedge CLK) begin
    if(RESET) begin
      pool_start <= #DELAY {log2(N){`FALSE}};
      pool_stride <= #DELAY {log2(N){`FALSE}};
      pool_mask <= #DELAY {log2(N){`FALSE}};
      
      p_wr_addr <= #DELAY {log2(N){`FALSE}};
      p_rd_addr <= #DELAY {log2(N){`FALSE}};
      q_wr_addr <= #DELAY {log2(N){`FALSE}};
      q_rd_addr <= #DELAY {log2(N){`FALSE}};
      r_wr_addr <= #DELAY {log2(N){`FALSE}};
      r_rd_addr <= #DELAY {log2(N){`FALSE}};
      s_wr_addr <= #DELAY {log2(N){`FALSE}};
      s_rd_addr <= #DELAY {log2(N){`FALSE}};

      pc_msg_ack <= #DELAY `FALSE;
      fpga_msg_valid <= #DELAY `FALSE;
      fpga_msg <= #DELAY 0;
      
      state <= #DELAY INIT;
    end else begin
      pool_start <= #DELAY rand[22+:10];
      pool_stride <= #DELAY {rand[13+:9], `TRUE};
      pool_mask <= #DELAY rand[3+:10];
      
      pc_msg_ack <= #DELAY `FALSE;
      
      p_rd_addr <= #DELAY (pool_start                             )^pool_mask;
      q_rd_addr <= #DELAY (pool_start                 +pool_stride)^pool_mask;
      r_rd_addr <= #DELAY (pool_start+(pool_stride<<1)            )^pool_mask;
      s_rd_addr <= #DELAY (pool_start+(pool_stride<<1)+pool_stride)^pool_mask;

      delayed_2nd_half_flag <= #DELAY
        {delayed_2nd_half_flag[0+:(TRANSFORM_LATENCY-1)]
        , intrapass_ctr[log2(N)-3]};

      case(state)
        INIT: begin
          if(pc_msg_valid) begin
            pool[p_wr_addr] <= #DELAY pc_msg;
            p_wr_addr <= #DELAY p_wr_addr + `TRUE;//Advance to the next spot
            pc_msg_ack <= #DELAY `TRUE;
            if(p_wr_addr == {log2(N){`TRUE}}) begin //the last address
              intrapass_ctr <= #DELAY {(log2(N)-2){`FALSE}};
              state <= #DELAY READY;
            end
          end
        end
        
        READY: begin
          intrapass_ctr <= #DELAY intrapass_ctr + `TRUE;
        end
        
        default: begin
        end
      endcase
    end
  end
`endif

endmodule
