module application#(parameter DELAY=1, SYNC_WINDOW=1, FP_SIZE=1, N_PATCH=1
, N_CAM=1)
( input CLK, RESET, output[7:0] GPIO_LED, output ready
, output[N_CAM-1:0] patch_ack, input[N_CAM-1:0] patch_val
, input[log2(N_PATCH)-1:0] patch_num0, patch_num1, patch_num2
, input[FP_SIZE-1:0] wtsum0, wtsum1, wtsum2);
`include "function.v"
  wire[N_CAM-1:0] not_patch;
  assign not_patch = {&patch_num[0], &patch_num[1], &patch_num[2]};

  genvar geni, genj;
  localparam BRAM_ADDR_SIZE = 10, BRAM_DATA_SIZE = FP_SIZE
    , BRAM_END_ADDR = {BRAM_ADDR_SIZE{`TRUE}}
    , N_BRAM = 2**(log2(SYNC_WINDOW) - BRAM_ADDR_SIZE);
  reg [log2(SYNC_WINDOW)-1:0] patch0_loc, wait4patch_loc;
  wire[log2(SYNC_WINDOW)-1:0] patch_loc[N_CAM-1:0];
  
  reg [log2(N_PATCH)-1:0] wait4patch;//The patch num to be completed
  wire[log2(N_PATCH)-1:0] wait4patch_plus_sync_window;
  assign wait4patch_plus_sync_window = wait4patch + SYNC_WINDOW;

  wire[log2(SYNC_WINDOW)-log2(N_BRAM)-1:0] wait4patch_row;
  wire[log2(N_BRAM)-1:0] wait4patch_col;
  assign {wait4patch_row, wait4patch_col} = wait4patch_loc;

  reg [BRAM_DATA_SIZE-1:0] din[N_CAM-1:0];
  wire[BRAM_DATA_SIZE-1:0] dout[N_CAM-1:0][N_BRAM-1:0];
  reg [FP_SIZE-1:0] sync_wtsum[N_CAM-1:0];
  reg sync_valid;
  wire[N_CAM-1:0] debug_hit, wait4patch_done;
  reg [N_CAM-1:0] wr_have_bit;
  reg have_bit;
  
  reg [N_BRAM-1:0] wren[N_CAM-1:0];
  reg [BRAM_ADDR_SIZE-1:0] wr_addr[N_CAM-1:0];
  wire[BRAM_ADDR_SIZE-1:0] rd_addr[N_CAM-1:0][N_BRAM-1:0];
  wire[N_BRAM-1:0] vout[N_CAM-1:0];
  wire[N_CAM-1:0] have_patch[N_BRAM-1:0];

  localparam INIT = 0, SOF_WAIT = 1, INTERFRAME = 2, ERROR = 3, N_STATE = 4;
  reg [log2(N_STATE)-1:0] state;
  assign ready = state == SOF_WAIT || state == INTERFRAME;

  generate
    for(geni=0; geni < N_CAM; geni=geni+1) begin
      for(genj=0; genj < N_BRAM; genj=genj+1) begin
        bram21 bram(.clka(CLK), .wea(wren[geni]), .addra(wr_addr)
                  , .dina({wr_have_bit, din[geni]})
                  , .clkb(CLK), .addrb(rd_addr[geni][genj])
                  , .doutb({vout[geni][genj], dout[geni][genj]})
                  , .sbiterr(), .dbiterr(), .rdaddrecc());
        assign rd_addr[geni][genj] = wait4patch_row + (geni < wait4patch_col);
        assign have_patch[geni] = vout[geni] == have_bit;
      end

      assign patch_ack[geni] = ready;
      assign debug_hit[geni] = patch_num[geni] == wait4patch[geni];
      assign wait4patch_done = &have_patch[wait4patch_col];
      assign patch_loc[geni] = patch_num[geni][log2(SYNC_WINDOW)-1:0]
                             + patch0_loc;
    end
  endgenerate

  reg [23:0] hb_ctr;
  assign GPIO_LED = {7'd0, hb_ctr[23]};
  
  integer i;
  always @(posedge CLK) begin
    din <= #DELAY wtsum;//Delay through register because wren is registered

    if(RESET) begin
      have_bit <= #DELAY `TRUE;
      for(i=0; i < N_CAM; i=i+1) begin
        wr_have_bit[i] <= #DELAY `FALSE;
        wr_addr[i] <= #DELAY 0;
        wren[i] <= #DELAY {N_BRAM{`TRUE}};
      end
      patch0_loc <= #DELAY 0;
      wait4patch_loc <= #DELAY 0;
      wait4patch <= #DELAY 0;
      sync_valid <= #DELAY `TRUE;
      state <= #DELAY INIT;
      //$display("%d ns: qptr %d, din %d", $time, qptr, din);
    end else begin
      case(state)
        INIT: begin // Write the starting valid bit to BRAM
          for(i=0; i < N_CAM; i=i+1) wr_addr[i] <= #DELAY wr_addr[i] + `TRUE;
          if(wr_addr[0] == BRAM_END_ADDR) begin
            for(i=0; i < N_CAM; i=i+1) wren[i] <= #DELAY 0;
            state <= #DELAY SOF_WAIT;
          end
        end
        
        SOF_WAIT: begin
          for(i=0; i < N_CAM; i=i+1) wren <= #DELAY 0;
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
