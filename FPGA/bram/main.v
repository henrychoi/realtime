module main(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
  localparam DELAY = 3;
  wire CLK;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  
  localparam BRAM_LATENCY = 5;
  reg[log2(BRAM_LATENCY)-1:0] bram_ptr;

  localparam BRAM_ADDR_SIZE = 10, BRAM_DATA_SIZE = 20;
  reg [BRAM_DATA_SIZE-1:0] din, expected_data;
  wire[BRAM_DATA_SIZE-1:0] dout[BRAM_LATENCY-1:0];
  wire vout[BRAM_LATENCY-1:0];
  reg wr_valid_bit[BRAM_LATENCY-1:0], rd_valid_bit[BRAM_LATENCY-1:0];
  
  reg [BRAM_ADDR_SIZE-1:0] qhead[BRAM_LATENCY-1:0]
                         , qtail[BRAM_LATENCY-1:0];
  wire[BRAM_ADDR_SIZE-1:0] qhead_plus1[BRAM_LATENCY-1:0];
  wire qfull[BRAM_LATENCY-1:0]
     , qempty[BRAM_LATENCY-1:0]
     , wren[BRAM_LATENCY-1:0];

  localparam INIT = 0, OK = 1, ERROR = 2, N_STATE = 3;
  reg [log2(N_STATE)-1:0] state;
  reg bwrite;
  reg [23:0] hb_ctr;
  assign GPIO_LED = {7'd0, hb_ctr[23]};
  
  genvar geni;
  generate  
    for(geni=0; geni < BRAM_LATENCY; geni=geni+1) begin
      bram21 bram(.clka(CLK), .wea(wren[geni]), .addra(qhead[geni])
                , .dina({wr_valid_bit[geni], din})
                , .clkb(CLK), .addrb(qtail[geni])
                , .doutb({vout[geni], dout[geni]})
                , .sbiterr(), .dbiterr(), .rdaddrecc());
                
      assign qhead_plus1[geni] = qhead[geni] + `TRUE;
      assign qfull[geni] = qhead_plus1[geni] == qtail[geni];
      assign qempty[geni] = qhead[geni] == qtail[geni];  
      assign wren[geni] = bwrite && !qfull[geni] && bram_ptr == geni;
    end
  endgenerate
    
  integer i;
  always @(posedge CLK)
    if(RESET) begin
      expected_data <= #DELAY 0;
      bram_ptr <= #DELAY 0; //BRAM_LATENCY - `TRUE;
      for(i=0; i < BRAM_LATENCY; i=i+1) begin
        qhead[i] <= #DELAY 0;
        qtail[i] <= #DELAY 0;
        wr_valid_bit[i] <= #DELAY `TRUE;
        rd_valid_bit[i] <= #DELAY `TRUE;
      end//for
      din <= #DELAY 0;
      //hb_ctr <= #DELAY 0;
      bwrite <= #DELAY `TRUE;
      state <= #DELAY INIT;
      //$display("%d ns: bram_ptr %d, din %d", $time, bram_ptr, din);
    end else begin
      for(i=0; i < BRAM_LATENCY; i=i+1) begin
        if(qhead[i] == {BRAM_ADDR_SIZE{`TRUE}})
          wr_valid_bit[i] <= #DELAY ~wr_valid_bit[i];
        if(qtail[i] == {BRAM_ADDR_SIZE{`TRUE}})
          rd_valid_bit[i] <= #DELAY ~rd_valid_bit[i];
      end//for
    
      case(state)
        INIT: begin
          //$display("%d ns: bram_ptr %d, din %d", $time, bram_ptr, din);
          bram_ptr <= #DELAY bram_ptr +`TRUE;
          din <= #DELAY din + `TRUE;
          qhead[bram_ptr] <= #DELAY qhead[bram_ptr] + `TRUE;
          if(bram_ptr == (BRAM_LATENCY-1)) begin
            bram_ptr <= #DELAY 0;
            //bwrite <= #DELAY `TRUE;
            state <= #DELAY OK;
          end
        end
        OK: begin
          bram_ptr <= #DELAY bram_ptr + `TRUE;
          if(bram_ptr == (BRAM_LATENCY-1)) bram_ptr <= #DELAY 0;
          if(qfull[bram_ptr]) begin //should not fill up; something's wrong
            state <= #DELAY ERROR;
          end else begin
            din <= #DELAY din + `TRUE;
            qhead[bram_ptr] <= #DELAY qhead[bram_ptr] + `TRUE;
            if(!qempty[bram_ptr]) begin
              if(dout[bram_ptr] == expected_data
                 && vout[bram_ptr] == rd_valid_bit[bram_ptr]) begin
                qtail[bram_ptr] <= #DELAY qtail[bram_ptr] + `TRUE;
                expected_data <= #DELAY expected_data + `TRUE;
                hb_ctr <= #DELAY hb_ctr + `TRUE;
              end else state <= #DELAY ERROR;
            end
          end
        end
        default: begin
        end
      endcase
    end
    
  reg [6:0] ro_bram_addr;
  wire[15:0] ro_bram_dout;
  RO_BRAM ro_bram(.clka(CLK), .wea(`FALSE), .addra(ro_bram_addr), .dina(16'h0000)
      , .douta(ro_bram_dout));
      
  always @(posedge CLK)
    if(RESET) ro_bram_addr <= #DELAY 0;
    else ro_bram_addr <= #DELAY ro_bram_addr + `TRUE;
endmodule
