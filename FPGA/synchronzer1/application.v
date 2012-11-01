module application#(parameter DELAY=1, SYNC_WINDOW=1, FP_SIZE=1, N_PATCH=1
, N_CAM=1)
( input CLK, RESET, output[7:0] GPIO_LED, output ready
, output[N_CAM-1:0] input_ack, input[N_CAM-1:0] input_val
, input[log2(N_PATCH)+FP_SIZE-1:0] aurora_data0, aurora_data1, aurora_data2);
`include "function.v"
  reg [23:0] hb_ctr;
  assign GPIO_LED = {7'd0, hb_ctr[23]};

  genvar geni, genj;
  localparam BRAM_ADDR_SIZE = 10, BRAM_DATA_SIZE = FP_SIZE
    , BRAM_END_ADDR = {BRAM_ADDR_SIZE{`TRUE}}
    , N_BRAM = 2**(log2(SYNC_WINDOW) - BRAM_ADDR_SIZE);
  reg [log2(SYNC_WINDOW)-1:0] patch0_loc, wait4patch_loc;
  wire[log2(SYNC_WINDOW)-1:0] patch_loc[N_CAM-1:0];
  wire[log2(N_PATCH)-1:0] patch_num[N_CAM-1:0];
  wire[FP_SIZE-1:0] wtsum[N_CAM-1:0];
  assign {patch_num[0], wtsum[0]} = aurora_data0;
  assign {patch_num[1], wtsum[1]} = aurora_data1;
  assign {patch_num[2], wtsum[2]} = aurora_data2;

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
  wire wait4patch_done;
  reg [N_CAM-1:0] wr_have_bit, eof;
  reg have_bit;
  
  reg [N_BRAM-1:0] wren[N_CAM-1:0];
  reg [BRAM_ADDR_SIZE-1:0] wr_addr[N_CAM-1:0];
  wire[BRAM_ADDR_SIZE-1:0] rd_addr[N_CAM-1:0][N_BRAM-1:0];
  wire[N_BRAM-1:0] vout[N_CAM-1:0];
  //This notation more convenient to test for completion across all cams
  wire[N_CAM-1:0] have_patch[N_BRAM-1:0], is_meta, is_sof;
  localparam ERROR = 0, INIT = 1, SOF_WAIT = 2, INTRAFRAME = 3, N_STATE = 4;
  reg [log2(N_STATE)-1:0] state;
  assign ready = state == SOF_WAIT || state == INTRAFRAME;

  generate
    for(geni=0; geni < N_CAM; geni=geni+1) begin
      for(genj=0; genj < N_BRAM; genj=genj+1) begin
        bram21 bram(.clka(CLK), .wea(wren[geni][genj]), .addra(wr_addr[geni])
                  , .dina({wr_have_bit[geni], din[geni]})
                  , .clkb(CLK), .addrb(rd_addr[geni][genj])
                  , .doutb({vout[geni][genj], dout[geni][genj]})
                  , .sbiterr(), .dbiterr(), .rdaddrecc());
        assign rd_addr[geni][genj] = wait4patch_row + (genj < wait4patch_col);
        assign have_patch[genj][geni] = vout[geni][genj] == have_bit;
      end

      assign input_ack[geni] = ready;
      assign patch_loc[geni] = patch_num[geni][log2(SYNC_WINDOW)-1:0]
                             + patch0_loc;
      assign is_meta[geni] = &patch_num[geni][1+:(log2(N_PATCH)-1)];
      assign is_sof[geni] = patch_num[geni][0];
    end
  endgenerate
  assign wait4patch_done = &have_patch[wait4patch_col];
  
  integer i, j;
  always @(posedge CLK) begin
    //Delay through register because wren is registered
    for(i=0; i < N_CAM; i=i+1) din[i] <= #DELAY wtsum[i];

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
      sync_valid <= #DELAY `FALSE;
      eof <= #DELAY 0;
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
          eof <= #DELAY 0;
          if((input_val[0] && is_meta[0] && is_sof[0])
          || (input_val[1] && is_meta[1] && is_sof[1])
          || (input_val[2] && is_meta[2] && is_sof[2]))
            state <= #DELAY INTRAFRAME;

          if(wait4patch_done) begin
            sync_valid <= #DELAY `TRUE;
            wait4patch <= #DELAY wait4patch == (N_PATCH - 1)
              ? 0 : wait4patch + `TRUE;

            wait4patch_loc <= #DELAY wait4patch_loc + `TRUE;
            for(i=0; i < N_CAM; i=i+1)
              sync_wtsum[i] <= #DELAY dout[i][wait4patch_col];

            if(&wait4patch_loc) have_bit <= #DELAY ~have_bit;//Rolling over
          end else sync_valid <= #DELAY `FALSE;
        end
        
        INTRAFRAME: begin //Can process received data          
          if(&eof) begin // Transition to SOF_WAIT
            eof <= #DELAY 0;
            patch0_loc <= #DELAY patch0_loc + (N_PATCH % SYNC_WINDOW);
            for(i=0; i < N_CAM; i=i+1) wren[i] <= #DELAY 0;
            state <= #DELAY SOF_WAIT;
          end else if((input_val[0] && !is_meta[0]
                       && patch_num[0] >= wait4patch_plus_sync_window)
                   || (input_val[1] && !is_meta[1]
                       && patch_num[1] >= wait4patch_plus_sync_window)
                   || (input_val[2] && !is_meta[2]
                       && patch_num[2] >= wait4patch_plus_sync_window))
            state <= #DELAY ERROR;

          for(i=0; i < N_CAM; i=i+1) begin
            if(input_val[i] && is_meta[i] && !is_sof[i]) // EOF
              eof[i] <= #DELAY `TRUE;

            for(j=0; j < N_BRAM; j=j+1) begin
              wren[i][j] <= #DELAY input_val[i] && !is_meta[i]
                         && j == patch_loc[i][0+:log2(N_BRAM)];
            end
            wr_addr[i] <= #DELAY // Pick off the MSB of the patch_loc
              patch_loc[i][log2(SYNC_WINDOW)-1:log2(N_BRAM)];
            wr_have_bit[i] <= #DELAY patch_loc[i] >= wait4patch_loc
              ? have_bit : ~have_bit;
          end

          if(wait4patch_done) begin
            sync_valid <= #DELAY `TRUE;
            wait4patch <= #DELAY wait4patch == (N_PATCH - 1)
              ? 0 : wait4patch + `TRUE;

            wait4patch_loc <= #DELAY wait4patch_loc + `TRUE;
            for(i=0; i < N_CAM; i=i+1)
              sync_wtsum[i] <= #DELAY dout[i][wait4patch_col];

            if(&wait4patch_loc) have_bit <= #DELAY ~have_bit;//Rolling over
          end else sync_valid <= #DELAY `FALSE;
        end//OK
        
        default: begin
          sync_valid <= #DELAY `FALSE;
          for(i=0; i < N_CAM; i=i+1) wren[i] <= #DELAY 0;
        end
      endcase
    end
  end//always
endmodule
