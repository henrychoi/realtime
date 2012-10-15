module main(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
  wire CLK;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  
  localparam BRAM_READ_LATENCY = 3;
  reg[log2(BRAM_READ_LATENCY):0] bram_ptr;

  localparam BRAM_ADDR_SIZE = 11, BRAM_DATA_SIZE = 21;
  reg [BRAM_DATA_SIZE-1:0] din, expected_data;
  wire[BRAM_DATA_SIZE-1:0] dout[BRAM_READ_LATENCY-1:0];
  
  reg [BRAM_ADDR_SIZE-1:0] qhead[BRAM_READ_LATENCY-1:0]
                         , qtail[BRAM_READ_LATENCY-1:0];
  wire[BRAM_ADDR_SIZE-1:0] qhead_plus1[BRAM_READ_LATENCY-1:0];
  wire qfull[BRAM_READ_LATENCY-1:0]
     , qempty[BRAM_READ_LATENCY-1:0]
     , wren[BRAM_READ_LATENCY-1:0];

  localparam WAIT = 0, OK = 1, ERROR = 2, N_STATE = 3;
  reg[log2(N_STATE)-1:0] state;
  
  reg [23:0] hb_ctr;
  assign GPIO_LED = hb_ctr[23-:8];
  
  genvar geni;
  generate  
    for(geni=0; geni < BRAM_READ_LATENCY; geni=geni+1) begin
      assign qhead_plus1[geni] = qhead[geni] + `TRUE;
      assign qfull[geni] = qhead_plus1[geni] == qtail[geni];
      assign qempty[geni] = qhead[geni] == qtail[geni];  
      assign wren[geni] = !RESET && !qfull[geni];
    end
  endgenerate
  
  integer i;
  always @(posedge CLK)
    if(RESET) begin
      expected_data <= 0;
      bram_ptr <= 0;
      for(i=0; i < BRAM_READ_LATENCY; i=i+1) begin
        qhead[i] <= 0;
        qtail[i] <= 0;
      end//for
      din <= 0;
      state <= WAIT;
      hb_ctr <= 0;
    end else begin
      case(state)
        WAIT: begin
          if(bram_ptr == BRAM_READ_LATENCY)
            state <= OK;//bram_ptr will be 0 in the next clk
          din <= din + `TRUE;
          qhead[bram_ptr] <= qhead[bram_ptr] + `TRUE;
          bram_ptr <= bram_ptr +`TRUE;
        end
        OK: begin
          bram_ptr <= bram_ptr - `TRUE;
          if(!qfull) begin
            din <= din + `TRUE;
            qhead <= qhead + `TRUE;
          end
          if(!bram_ptr && !qempty) begin
            bram_ptr <= BRAM_READ_LATENCY;
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
