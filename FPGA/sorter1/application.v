module application#(parameter DELAY=1, SYNC_WINDOW=1, FP_SIZE=1, N_PATCH=1)
( input CLK, RESET, output[7:0] GPIO_LED, output ready, patch_ack
, input patch_val, input[log2(N_PATCH)-1:0] patch_num
, input[FP_SIZE-1:0] wtsum);
`include "function.v"
  wire not_patch = &patch_num;

  localparam BRAM_ADDR_SIZE = 10, BRAM_DATA_SIZE = FP_SIZE
    , BRAM_END_ADDR = {BRAM_ADDR_SIZE{`TRUE}}
    , N_BRAM = 2**(log2(SYNC_WINDOW) - BRAM_ADDR_SIZE);
  reg [log2(SYNC_WINDOW)-1:0] patch0_loc, wait4patch_loc;
  wire[log2(SYNC_WINDOW)-1:0] patch_loc;
  assign patch_loc = patch_num[log2(SYNC_WINDOW)-1:0] + patch0_loc;

  reg [log2(N_PATCH)-1:0] wait4patch;//The patch num to be completed
  wire[log2(N_PATCH)-1:0] wait4patch_plus_sync_window;
  assign wait4patch_plus_sync_window = wait4patch + SYNC_WINDOW;

  wire[log2(SYNC_WINDOW)-log2(N_BRAM)-1:0] wait4patch_row;
  wire[log2(N_BRAM)-1:0] wait4patch_col;
  assign {wait4patch_row, wait4patch_col} = wait4patch_loc;

  wire debug_hit, wait4patch_done;
  assign debug_hit = patch_num == wait4patch;
  assign wait4patch_done = have_patch[wait4patch_col];
  
  reg [BRAM_DATA_SIZE-1:0] din;
  wire[BRAM_DATA_SIZE-1:0] dout[N_BRAM-1:0];
  reg [FP_SIZE-1:0] sync_wtsum;
  reg sync_valid;
  
  reg have_bit, wr_have_bit;
  
  reg [N_BRAM-1:0] wren;
  reg [BRAM_ADDR_SIZE-1:0] wr_addr;
  wire[BRAM_ADDR_SIZE-1:0] rd_addr[N_BRAM-1:0];
  wire[N_BRAM-1:0] vout, have_patch;

  localparam INIT = 0, SOF_WAIT = 1, INTERFRAME = 2, ERROR = 3, N_STATE = 4;
  reg [log2(N_STATE)-1:0] state;
  assign ready = state == SOF_WAIT || state == INTERFRAME;
  assign patch_ack = ready;

  reg [23:0] hb_ctr;
  assign GPIO_LED = {7'd0, hb_ctr[23]};
  
  genvar geni;
  generate  
    for(geni=0; geni < N_BRAM; geni=geni+1) begin
      bram21 bram(.clka(CLK), .wea(wren[geni]), .addra(wr_addr)
                , .dina({wr_have_bit, din})
                , .clkb(CLK), .addrb(rd_addr[geni])
                , .doutb({vout[geni], dout[geni]})
                , .sbiterr(), .dbiterr(), .rdaddrecc());
      assign rd_addr[geni] = wait4patch_row + (geni < wait4patch_col);
      assign have_patch[geni] = vout[geni] == have_bit;
    end
  endgenerate

  integer i;
  always @(posedge CLK) begin
    din <= #DELAY wtsum;//Delay through register because wren is registered

    if(RESET) begin
      have_bit <= #DELAY `TRUE;
      wr_have_bit <= #DELAY `FALSE;
      wr_addr <= #DELAY 0;
      patch0_loc <= #DELAY 0;
      wait4patch_loc <= #DELAY 0;
      wren <= #DELAY {N_BRAM{`TRUE}};
      wait4patch <= #DELAY 0;
      sync_valid <= #DELAY `FALSE;
      state <= #DELAY INIT;
      //$display("%d ns: qptr %d, din %d", $time, qptr, din);
    end else begin
      case(state)
        INIT: begin // Write the starting valid bit to BRAM
          wr_addr <= #DELAY wr_addr + `TRUE;
          if(wr_addr == BRAM_END_ADDR) begin
            wren <= #DELAY 0;
            state <= #DELAY SOF_WAIT;
          end
        end
        
        SOF_WAIT: begin
          wren <= #DELAY 0;
          if(not_patch && wtsum == 1) state <= #DELAY INTERFRAME;

          sync_valid <= #DELAY wait4patch_done;
          if(wait4patch_done) begin
            wait4patch <= #DELAY wait4patch == (N_PATCH - 1)
              ? 0 : wait4patch + `TRUE;
            wait4patch_loc <= #DELAY wait4patch_loc + `TRUE;
            sync_wtsum <= #DELAY dout[wait4patch_col];

            if(&wait4patch_loc) have_bit <= #DELAY ~have_bit;//Rolling over
          end
        end
        
        INTERFRAME: begin //Process received patch          
          if(!not_patch
             //On new frame patch_num will be 0 while wait4patch is near end
             && patch_num >= wait4patch_plus_sync_window)
            state <= #DELAY ERROR;
          else begin
            for(i=0; i < N_BRAM; i=i+1)
              wren[i] <= #DELAY patch_val && i == patch_loc[0+:log2(N_BRAM)];
              
            // Pick off the MSB of the patch_loc
            wr_addr <= #DELAY patch_loc[log2(SYNC_WINDOW)-1:log2(N_BRAM)];
            wr_have_bit <= #DELAY patch_loc >= wait4patch_loc
              ? have_bit : ~have_bit;

            if(not_patch) begin //No need to check for EOF
              //Next frame starts here
              patch0_loc <= #DELAY patch0_loc + (N_PATCH % SYNC_WINDOW);
              wren <= #DELAY 0;
              state <= #DELAY SOF_WAIT;
            end

            //Handle completed patch
            sync_valid <= #DELAY wait4patch_done;            
            if(wait4patch_done) begin
              wait4patch <= #DELAY wait4patch == (N_PATCH - 1)
                ? 0 : wait4patch + `TRUE;

              wait4patch_loc <= #DELAY wait4patch_loc + `TRUE;
              sync_wtsum <= #DELAY dout[wait4patch_col];

              if(&wait4patch_loc) have_bit <= #DELAY ~have_bit;//Rolling over

              //$display("%d wait4patch: %d, sync_wtsum: %d, have_bit: %d"
              //  , $time, wait4patch, dout[wait4patch_col], have_bit);
            end
          end
        end
        
        default: begin
          sync_valid <= #DELAY `FALSE;
          wren <= #DELAY 0;
        end
      endcase
    end
  end//always
endmodule
