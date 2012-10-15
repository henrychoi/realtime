module main(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
  wire CLK;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  
  localparam BRAM_ADDR_SIZE = 11, BRAM_DATA_SIZE = 21;
  reg [BRAM_DATA_SIZE-1:0] din, expected_data;
  wire[BRAM_DATA_SIZE-1:0] dout;
  
  reg [BRAM_ADDR_SIZE-1:0] qhead, qtail;
  wire[BRAM_ADDR_SIZE-1:0] qhead_plus1;
  wire qfull, qempty;
  
  assign qhead_plus1 = qhead + `TRUE;
  assign qfull = qhead_plus1 == qtail;
  assign qempty = qhead == qtail;
  
  localparam BRAM_WRITE_LATENCY = 1, BRAM_READ_LATENCY = 2
    , BRAM_LATENCY = BRAM_WRITE_LATENCY + BRAM_READ_LATENCY;
  reg[log2(BRAM_LATENCY):0] delay_ctr;
  wire wren;
  assign wren = !RESET && !qfull;
  
  localparam ERROR = 0, OK = 1, N_STATE = 2;
  reg[log2(N_STATE)-1:0] state;
  
  reg [23:0] hb_ctr;
  assign GPIO_LED = hb_ctr[23-:8];
  
  always @(posedge CLK)
    if(RESET) begin
      qhead <= 0;
      qtail <= 0;
      delay_ctr <= BRAM_LATENCY;
      din <= 0;
      expected_data <= 0;
      state <= OK;
      hb_ctr <= 0;
    end else begin
      case(state)
        OK: begin
          delay_ctr <= delay_ctr - `TRUE;
          if(!qfull) begin
            din <= din + `TRUE;
            qhead <= qhead + `TRUE;
          end
          if(!delay_ctr && !qempty) begin
            delay_ctr <= BRAM_LATENCY;
            if(dout == expected_data) begin
              qtail <= qtail + `TRUE;
              expected_data <= expected_data + `TRUE;
              hb_ctr <= hb_ctr + `TRUE;
            end else state <= ERROR;
          end
        end
        default: begin
        end
      endcase
    end
  
  bram21 bram(.clka(CLK), .wea(wren), .addra(qhead), .dina(din)
            , .clkb(CLK), .addrb(qtail), .doutb(dout)
            , .sbiterr(), .dbiterr(), .rdaddrecc());
endmodule
