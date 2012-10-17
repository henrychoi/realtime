module application#(parameter DELAY=1, N_PATCH=1, FP_SIZE=1)
( input CLK, RESET, output[7:0] GPIO_LED, output ready, patch_ack
, input patch_val, input[log2(N_PATCH)-1:0] patch_num
, input[FP_SIZE-1:0] wtsum);
`include "function.v"
  localparam N_BRAM = 8, BRAM_ADDR_SIZE = 10, BRAM_DATA_SIZE = 20
    , BRAM_ADDR_END = {BRAM_ADDR_SIZE{`TRUE}};
  reg[log2(N_BRAM)-1:0] bram_ptr;
  reg [BRAM_DATA_SIZE-1:0] din, expected_data;
  wire[BRAM_DATA_SIZE-1:0] dout[N_BRAM-1:0];
  wire vout[N_BRAM-1:0];
  reg wr_valid_bit[N_BRAM-1:0], rd_valid_bit[N_BRAM-1:0];
  
  reg [BRAM_ADDR_SIZE-1:0] qhead[N_BRAM-1:0]
                         , qtail[N_BRAM-1:0];
  wire[BRAM_ADDR_SIZE-1:0] qhead_plus1[N_BRAM-1:0];
  wire qfull[N_BRAM-1:0], qempty[N_BRAM-1:0];
  reg  wren[N_BRAM-1:0];

  localparam INIT = 0, READY = 1, ERROR = 2, N_STATE = 3;
  reg [log2(N_STATE)-1:0] state;
  assign ready = state == READY;

  reg [23:0] hb_ctr;
  assign GPIO_LED = {7'd0, hb_ctr[23]};
  
  genvar geni;
  generate  
    for(geni=0; geni < N_BRAM; geni=geni+1) begin
      bram21 bram(.clka(CLK), .wea(wren[geni]), .addra(qhead[geni])
                , .dina({wr_valid_bit[geni], din})
                , .clkb(CLK), .addrb(qtail[geni])
                , .doutb({vout[geni], dout[geni]})
                , .sbiterr(), .dbiterr(), .rdaddrecc());
                
      assign qhead_plus1[geni] = qhead[geni] + `TRUE;
      assign qfull[geni] = qhead_plus1[geni] == qtail[geni];
      assign qempty[geni] = qhead[geni] == qtail[geni];  
    end
  endgenerate
    
  integer i;
  always @(posedge CLK)
    if(RESET) begin
      expected_data <= #DELAY 0;
      bram_ptr <= #DELAY 0; //N_BRAM - `TRUE;
      for(i=0; i < N_BRAM; i=i+1) begin
        qhead[i] <= #DELAY 0;
        qtail[i] <= #DELAY 0;
        wr_valid_bit[i] <= #DELAY `FALSE;
        rd_valid_bit[i] <= #DELAY `TRUE;
        wren[i] <= #DELAY `TRUE;
      end//for
      din <= #DELAY 0;
      state <= #DELAY INIT;
      //$display("%d ns: bram_ptr %d, din %d", $time, bram_ptr, din);
    end else begin
      for(i=0; i < N_BRAM; i=i+1) begin
        if(qhead[i]==BRAM_ADDR_END)
          wr_valid_bit[i] <= #DELAY ~wr_valid_bit[i];
        if(qtail[i]==BRAM_ADDR_END)
          rd_valid_bit[i] <= #DELAY ~rd_valid_bit[i];
      end//for
    
      case(state)
        INIT: begin // Write the starting valid bit to BRAM
          for(i=0; i < N_BRAM; i=i+1) qhead[i] <= #DELAY qhead[i] + `TRUE;
          if(qhead[0] == BRAM_ADDR_END) begin
            for(i=0; i < N_BRAM; i=i+1) wren[i] <= #DELAY `FALSE;
            state <= #DELAY READY;
          end
        end
        READY: begin
        end
        default: begin
        end
      endcase
    end
endmodule
