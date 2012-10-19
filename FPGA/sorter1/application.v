module application#(parameter DELAY=1, SYNC_WINDOW=1, FP_SIZE=1, N_PATCH=1)
( input CLK, RESET, output[7:0] GPIO_LED, output ready, patch_ack
, input patch_val, input[log2(N_PATCH)-1:0] patch_num
, input[FP_SIZE-1:0] wtsum);
`include "function.v"
  localparam BRAM_ADDR_SIZE = 10, BRAM_DATA_SIZE = FP_SIZE
    , BRAM_END_ADDR = {BRAM_ADDR_SIZE{`TRUE}}
    , N_BRAM = 2**(log2(SYNC_WINDOW) - BRAM_ADDR_SIZE);
  wire[log2(N_BRAM)-1:0] wr_qptr, rd_qptr;
  reg [BRAM_DATA_SIZE-1:0] din;
  wire[BRAM_DATA_SIZE-1:0] dout[N_BRAM-1:0];
  wire vout[N_BRAM-1:0];
  reg wr_valid_bit, rd_valid_bit[N_BRAM-1:0];
  
  reg [BRAM_ADDR_SIZE-1:0] wr_addr, rd_addr[N_BRAM-1:0];
  wire[BRAM_ADDR_SIZE-1:0] qhead_plus1;
  wire[N_BRAM-1:0] qfull, qempty, completed_patch_avail;
  reg  wren[N_BRAM-1:0];

  localparam INIT = 0, READY = 1, ERROR = 2, N_STATE = 3;
  reg [log2(N_STATE)-1:0] state;
  assign ready = state == READY;
  
  reg [log2(N_PATCH)-1:0] wait4patch;//The patch num to be completed
  wire[log2(N_PATCH)-1:0] wait4patch_plus_sync_window;
  wire[log2(SYNC_WINDOW):0] offset_from_wait4;
  //wire[log2(SYNC_WINDOW)-1:0] qpos;

  // Simulate a patch number received over Aurora
  assign wait4patch_plus_sync_window = wait4patch + SYNC_WINDOW;
  assign offset_from_wait4 = patch_num[log2(SYNC_WINDOW):0]
                           - wait4patch[log2(SYNC_WINDOW):0];
  //assign qpos = offset_from_wait4[0:log2(SYNC_WINDOW)];
  assign wr_qptr = patch_num[0+:log2(N_BRAM)];
  assign rd_qptr = wait4patch[0+:log2(N_BRAM)];
  
  assign patch_ack = !(|qfull);

  reg [23:0] hb_ctr;
  assign GPIO_LED = {7'd0, hb_ctr[23]};
  
  genvar geni;
  generate  
    for(geni=0; geni < N_BRAM; geni=geni+1) begin
      bram21 bram(.clka(CLK), .wea(wren[geni]), .addra(wr_addr)
                , .dina({wr_valid_bit, din})
                , .clkb(CLK), .addrb(rd_addr[geni])
                , .doutb({vout[geni], dout[geni]})
                , .sbiterr(), .dbiterr(), .rdaddrecc());
                
      assign qfull[geni] = qhead_plus1 == rd_addr[geni];
      assign qempty[geni] = wr_addr == rd_addr[geni];  
      assign completed_patch_avail[geni] = vout[geni] == rd_valid_bit[geni];
    end
  endgenerate
  assign qhead_plus1 = wr_addr + `TRUE;

  integer i;
  always @(posedge CLK) begin
    din <= #DELAY wtsum;//Delay through register because wren is registered

    if(RESET) begin
      wr_valid_bit <= #DELAY `FALSE;
      wr_addr <= #DELAY 0;
      for(i=0; i < N_BRAM; i=i+1) begin
        rd_addr[i] <= #DELAY 0;
        rd_valid_bit[i] <= #DELAY `TRUE;
        wren[i] <= #DELAY `TRUE;
      end//for
      wait4patch <= #DELAY 0;
      state <= #DELAY INIT;
      //$display("%d ns: qptr %d, din %d", $time, qptr, din);
    end else begin
      if(wr_addr == BRAM_END_ADDR) wr_valid_bit <= #DELAY ~wr_valid_bit;

      for(i=0; i < N_BRAM; i=i+1) begin
        if(rd_addr[i] == BRAM_END_ADDR)
          rd_valid_bit[i] <= #DELAY ~rd_valid_bit[i];
      end//for
    
      case(state)
        INIT: begin // Write the starting valid bit to BRAM
          wr_addr <= #DELAY wr_addr + `TRUE;
          if(wr_addr == BRAM_END_ADDR) begin
            for(i=0; i < N_BRAM; i=i+1) wren[i] <= #DELAY `FALSE;
            state <= #DELAY READY;
          end
        end
        READY: begin //Process received patch
          //Q availability check; checking all queues rather than only wr_qptr
          //will probably make timing easier to meet.  Extra logic cost to
          //check all queues is neglible.
          for(i=0; i < N_BRAM; i=i+1) begin
            if(qfull[i]) begin
              $display("%d ns: qfull[%d]", $time, i);
              state <= #DELAY ERROR;
            end
          end
          
          if(patch_num < wait4patch //Bounds check
             || patch_num >= wait4patch_plus_sync_window)
            state <= #DELAY ERROR;
          else begin
            for(i=0; i < N_BRAM; i=i+1)
              wren[i] <= #DELAY patch_val && i == wr_qptr;
            wr_addr <= #DELAY rd_addr[rd_qptr] //Pick the right Q
                     + offset_from_wait4[log2(SYNC_WINDOW):log2(N_BRAM)];
            if(completed_patch_avail[rd_qptr]) begin
              //Emit and increment wait4patch
              wait4patch <= #DELAY wait4patch + `TRUE;
              rd_addr[rd_qptr] <= #DELAY rd_addr[rd_qptr] + `TRUE;
            end
          end
        end
        default: begin
        end
      endcase
    end
  end//always
endmodule
