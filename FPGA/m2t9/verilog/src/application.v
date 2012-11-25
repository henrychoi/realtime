`timescale 1 ps/1 ps

module application#(parameter SIMULATION=0, DELAY=1
, XB_SIZE=1,ADDR_WIDTH=1, APP_DATA_WIDTH=1)
(input RESET, CLK, output error, output[7:4] GPIO_LED
, input app_rdy, output reg app_en, output reg dram_read
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
, input PCIe_CLK
, input pc_msg_pending, output pc_msg_ack, input[XB_SIZE-1:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[XB_SIZE-1:0] fpga_msg
);
`include "function.v"
  integer i, j;
  localparam HB_CTR_SIZE = 16;
  reg[HB_CTR_SIZE-1:0] hb_ctr;

  reg[3:0] n_pc_dram_msg;// = 2 * 256/32
  
  wire pc_msg_is_ds;
  //reg pc_msg_is_ds_d, pc_msg_pending_d;
  wire[XB_SIZE-1:0] dram_msg;
  wire[2*(XB_SIZE-4)-1:0] pixel_msg;
  reg[XB_SIZE-1:0] pc_msg_d;
  wire xb2pixel_full, xb2dram_full, xb2pixel_empty, xb2dram_empty, xb2dram_valid
    , xb2pixel_ack, xb2dram_ack, xb2dram_overflow;
  reg xb2pixel_wren, xb2dram_wren; //Delay through register

  localparam N_PIXEL_STATE = 5
    , PIXEL_ERROR = 3'd0
    , PIXEL_STANDBY = 3'd1
    , PIXEL_INTRALINE = 3'd2
    , PIXEL_INTERLINE = 3'd3
    , PIXEL_INTERFRAME = 3'd4;
  reg[log2(N_PIXEL_STATE)-1:0] pixel_state;

  localparam FP_SIZE=20
    , N_FRAME_SIZE = 20
    , N_COL_MAX = 2048, N_ROW_MAX = 2064 //2k rows + 8 dark pixels top and btm
    , PATCH_SIZE = 12//, PATCH_SIZE_MAX = 16
    , N_PATCH = 600000 //Can handle up to 1M
    , N_PIXEL_PER_CLK = 2'd2
    , N_ROW_REDUCER = 4;
  reg[N_FRAME_SIZE-1:0] n_frame;
  reg[log2(N_ROW_MAX)-1:0] n_row;//, n_row_d[N_FADD_LATENCY-1:0];
  reg[log2(N_COL_MAX)-1:0] l_col;//, n_col_d[N_FADD_LATENCY-1:0];
  //reg[0:0] init_reducer_d;
  reg [PATCH_SIZE-1:0] init_a_reducer, a_reducer_done;
  reg [N_ROW_REDUCER-1:0] init_the_reducer[PATCH_SIZE-1:0];
  wire[N_ROW_REDUCER-1:0] the_reducer_avail[PATCH_SIZE-1:0]
                        , the_reducer_done[PATCH_SIZE-1:0];
  wire[log2(N_ROW_REDUCER)-1:0] avail_reducer_idx[PATCH_SIZE-1:0];
  wire dramifc_overflow;

  localparam INTERLINE_DATA_SIZE
    = log2(N_PATCH) + log2(N_ROW_MAX) + log2(N_COL_MAX) + FP_SIZE;
  reg [FP_SIZE-1:0] result_patch_sum //The final answer
                  , interline_sum_in[PATCH_SIZE-1:1];
  wire[FP_SIZE-1:0] interline_sum_out[PATCH_SIZE-1:0]
                  , reducer_sum[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0];
  reg [log2(N_PATCH)-1:0] result_patch_num //The ID of the final answer
                        , interline_num_in[PATCH_SIZE-1:1];
  wire[log2(N_PATCH)-1:0] interline_num_out[PATCH_SIZE-1:0]
                        , reducer_num[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0];
  reg [log2(N_ROW_MAX)-1:0] interline_row_in[PATCH_SIZE-1:1];
  wire[log2(N_ROW_MAX)-1:0] interline_row_out[PATCH_SIZE-1:0]
                          , reducer_row[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0];
  reg [log2(N_COL_MAX)-1:0] interline_col_in[PATCH_SIZE-1:1];
  wire[log2(N_COL_MAX)-1:0] interline_col_out[PATCH_SIZE-1:0]
                          , reducer_col[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0];
  wire[PATCH_SIZE-1:1] interline_fifo_overflow, interline_fifo_empty;
  wire[PATCH_SIZE-1:0] row_coeff_fifo_overflow, row_coeff_fifo_high
                     , row_coeff_fifo_empty/*, row_coeff_fifo_full*/;
  wire patch_coeff_fifo_overflow, patch_coeff_fifo_high
     , patch_coeff_fifo_empty/*, patch_coeff_fifo_full*/;

  // Config variables
  localparam PATCH_CONF_SIZE = 43
     , ROW_REDUCER_CONFIG_SIZE = PATCH_SIZE * FP_SIZE;// This may be too wide
  reg [ROW_REDUCER_CONFIG_SIZE-1:0] row_conf;
  reg [PATCH_CONF_SIZE-1:0] patch_conf;
  reg patch_conf_valid;
  reg [PATCH_SIZE-1:0] row_conf_valid;
  wire[(PATCH_SIZE * FP_SIZE)-1:0] conf_weights[PATCH_SIZE-1:0];
  //reg[(PATCH_SIZE * FP_SIZE)-1:0] fst_row_weights;
  wire fval, lval, fds_val;
  reg fds_val_d;
  //Data always flows (can't stop it); need to distinguish whether it is valid
  //pval (pixel valid) indicates whether this is a legitimate data received from
  //the "camera".  Note one more delay to sync up with the sampled fds_val from
  //the sequential logic
  reg pval_d, fval_d, lval_d, val_d;
  wire[FP_SIZE-1:0] fds[N_PIXEL_PER_CLK-1:0];
  //reg[FP_SIZE-1:0] fds_d;

  //wire[APP_DATA_WIDTH-1:0] dram_data;
                     
  reg[ADDR_WIDTH-1:0] end_addr;
  localparam START_ADDR = 27'h000_0000//, END_ADDR = 27'h3ff_fffc;
    , ADDR_INC = 4'd8;// BL8
  localparam DRAMIFC_N_STATE = 8
    , DRAMIFC_ERROR = 3'd0
    , DRAMIFC_WR1 = 3'd1
    , DRAMIFC_WR2 = 3'd2
    , DRAMIFC_MSG_WAIT = 3'd3
    , DRAMIFC_WR_WAIT = 3'd4
    , DRAMIFC_READING = 3'd5
    , DRAMIFC_THROTTLED = 3'd6
    , DRAMIFC_INTERFRAME = 3'd7;
  reg[log2(DRAMIFC_N_STATE)-1:0] dramifc_state;
  reg[APP_DATA_WIDTH*2-1:0] tmp_data;
  //Note: designed deliberately 1 bit short to wrap automatically even when I
  //simply increment
  reg[log2(APP_DATA_WIDTH*2-1)-1:0] tmp_data_offset;
  
`ifdef REDUCER_HAS_TO_BE_ALWAYS_AVAILABLE
  localparam COEFFRD_ERROR = 0, COEFFRD_OK = 1, N_COEFFRD_STATE = 2;
  reg[log2(N_COEFFRD_STATE)-1:0] coeffrd_state[PATCH_SIZE-1:0];
`endif

  assign error = dramifc_state == DRAMIFC_ERROR
    || (pixel_state == PIXEL_ERROR);
  //assign heartbeat = hb_ctr[HB_CTR_SIZE-1];
  assign pc_msg_ack = pc_msg_pending && !xb2pixel_full && !xb2dram_full;  
  assign {fval, lval} = pixel_msg[0+:2];
  assign fds[0] = pixel_msg[(XB_SIZE-4+8)+:FP_SIZE];//Note: throw away the 4 LSB
  assign fds[1] = pixel_msg[8+:FP_SIZE];//Note: throw away the 4 LSB
  // This works only if I ack the xb2pixel fifo as soon as it is !empty
  // Using combinational logic to ack FIFO is necessary for the FWFT feature
  assign xb2pixel_ack = !patch_coeff_fifo_empty && !row_coeff_fifo_empty;
    //&& !xb2pixel_empty;//Not necessary to check
  assign xb2dram_ack = !xb2dram_empty
   && !(dramifc_state == DRAMIFC_WR1 || dramifc_state == DRAMIFC_WR2
        || dramifc_state == DRAMIFC_WR_WAIT);
  //assign xb2pixel_wren = !xb2pixel_full && pc_msg_pending_d &&  pc_msg_is_ds_d;
  //assign xb2dram_wren  = !xb2dram_full  && pc_msg_pending_d && !pc_msg_is_ds_d;
  assign pc_msg_is_ds = pc_msg[1:0] == 2'b00 && n_pc_dram_msg == 0;
  assign dramifc_overflow = patch_coeff_fifo_overflow
                         || |row_coeff_fifo_overflow;

  // Builtin FIFO does NOT offer ALMOST_full port
  better_fifo#(.DELAY(DELAY), .FIFO_CLASS("xb2dram")
    , .WR_WIDTH(XB_SIZE), .RD_WIDTH(XB_SIZE))
    xb2dram(.RESET(RESET)
    , .WR_CLK(CLK), .wren(xb2dram_wren), .din(pc_msg_d)
    , .full(xb2dram_full), .overflow(xb2dram_overflow)
    , .RD_CLK(CLK), .rden(xb2dram_ack), .dout(dram_msg)
    , .empty(xb2dram_empty));

  better_fifo#(.DELAY(DELAY), .FIFO_CLASS("xb2pixel")
    , .WR_WIDTH(XB_SIZE-4), .RD_WIDTH(2*(XB_SIZE-4)))
    xb2pixel (.RESET(RESET)
    , .WR_CLK(CLK), .wren(xb2pixel_wren), .din(pc_msg_d[XB_SIZE-1:4])
    , .full(xb2pixel_full), .overflow()
    , .RD_CLK(CLK), .rden(xb2pixel_ack), .dout(pixel_msg)
    , .empty(xb2pixel_empty));

  better_fifo#(.DELAY(DELAY), .FIFO_CLASS("patch_coeff")
    , .WR_WIDTH(PATCH_CONF_SIZE), .RD_WIDTH(PATCH_CONF_SIZE))
    patch_fifo(.RESET(RESET)
    , .WR_CLK(CLK), .din(patch_conf), .wren(patch_conf_valid)
    , .full(patch_coeff_fifo_high), .overflow(patch_coeff_fifo_overflow)
    , .RD_CLK(CLK), .rden(init_a_reducer[0]) //If I just used a coeff, get more
    , .dout({interline_col_out[0], interline_row_out[0], interline_num_out[0]})
    , .empty(patch_coeff_fifo_empty));

  assign GPIO_LED[7:4] = {app_rdy, dramifc_state};
  
  //assign init_a_reducer[0] = !patch_coeff_fifo_empty
  //  && !row_coeff_fifo_empty[0] && |the_reducer_avail[0];
      
  assign interline_sum_out[0] = {FP_SIZE{`FALSE}}; //first row starts at 0.0f

  genvar geni, genj;
  generate
    for(geni=0; geni < PATCH_SIZE; geni=geni+1) begin: for_all_patch_rows
      //Note: I do not check whether the last reducer is actually available
      //(|the_reducer_avail[geni]) would tell if no reducer is available at all
      //This is only used in sequential logic that decides which reducer to
      //grab, so it's probably OK to leave it as a combinational logic
      assign avail_reducer_idx[geni]
        = the_reducer_avail[geni][0] ? 0
        : the_reducer_avail[geni][1] ? 1
        : the_reducer_avail[geni][2] ? 2
        /*: the_reducer_avail[geni][3] ? 3
        : the_reducer_avail[geni][4] ? 4
        : the_reducer_avail[geni][5] ? 5
        : the_reducer_avail[geni][6] ? 6
        : the_reducer_avail[geni][7] ? 7
        : the_reducer_avail[geni][8] ? 8
        : the_reducer_avail[geni][9] ? 9
        : the_reducer_avail[geni][10] ? 10
        : the_reducer_avail[geni][11] ? 11
        : the_reducer_avail[geni][12] ? 12*/
        :                              (N_ROW_REDUCER - 1);

      better_fifo#(.DELAY(DELAY), .FIFO_CLASS("row_coeff")
        , .WR_WIDTH(ROW_REDUCER_CONFIG_SIZE)
        , .RD_WIDTH(ROW_REDUCER_CONFIG_SIZE))
        row_fifo(.RESET(RESET), .WR_CLK(CLK)
        , .wren(row_conf_valid[geni]), .din(row_conf)
        , .full(row_coeff_fifo_high[geni])
        , .overflow(row_coeff_fifo_overflow[geni])
        , .RD_CLK(CLK), .rden(init_a_reducer[geni])
        , .dout(conf_weights[geni]), .empty(row_coeff_fifo_empty[geni]));

      for(genj=0; genj < N_ROW_REDUCER; genj=genj+1) begin: row_reducers
        PatchRowReducer#(.DELAY(DELAY)
            , .N_PATCH(N_PATCH), .PATCH_SIZE(PATCH_SIZE)
            , .FP_SIZE(FP_SIZE), .N_PIXEL_PER_CLK(N_PIXEL_PER_CLK)
            , .N_COL_SIZE(log2(N_COL_MAX)), .N_ROW_SIZE(log2(N_ROW_MAX)))
          row_reducer(.CLK(CLK), .RESET(RESET)
          , .available(the_reducer_avail[geni][genj])
          , .init(init_the_reducer[geni][genj])
          , .conf_row(interline_row_out[geni])
          , .conf_col(interline_col_out[geni])
          , .conf_sum(interline_sum_out[geni])
          , .conf_patch_num(interline_num_out[geni])
          , .conf_weights(conf_weights[geni])
          , .cur_row(n_row), .l_col(l_col)
          , .fds_val_in(lval /*lval_d*/), .fds0(fds[0]), .fds1(fds[1])
          , .done(the_reducer_done[geni][genj])
          , .patch_num(reducer_num[geni][genj]), .sum(reducer_sum[geni][genj])
          , .matcher_row(reducer_row[geni][genj])
          , .start_col(reducer_col[geni][genj]));
      end//for genj
    end//for geni

    for(geni=1; geni < PATCH_SIZE; geni=geni+1) begin: interline
      better_fifo#(.DELAY(DELAY), .FIFO_CLASS("interline")
        , .WR_WIDTH(INTERLINE_DATA_SIZE), .RD_WIDTH(INTERLINE_DATA_SIZE))
        interline_fifo(.RESET(RESET), .WR_CLK(CLK)
        //When a previous row's sum is ready, move that into the interline fifo
        , .wren(a_reducer_done[geni-1])
        , .din({interline_num_in[geni], interline_row_in[geni]
              , interline_sum_in[geni], interline_col_in[geni]})
        , .full(), .overflow(interline_fifo_overflow[geni])
        , .RD_CLK(CLK), .rden(init_a_reducer[geni])
        , .dout({interline_num_out[geni], interline_row_out[geni]
               , interline_sum_out[geni], interline_col_out[geni]})
        , .empty(interline_fifo_empty[geni]));
            
      //assign init_a_reducer[geni] = !interline_fifo_empty[geni]
      //  && !row_coeff_fifo_empty[geni] && |the_reducer_avail[geni];
    end//for geni
  endgenerate
  
  always @(posedge RESET, posedge fds_val)
    if(RESET) hb_ctr <= #DELAY 0;
    else hb_ctr <= #DELAY hb_ctr + `TRUE;

  always @(posedge CLK)
    if(RESET) begin
      xb2pixel_wren <= #DELAY `FALSE;
      xb2dram_wren <= #DELAY `FALSE;
      n_pc_dram_msg <= #DELAY 0;
      //pc_msg_pending_d <= #DELAY `FALSE;
  		app_addr <= #DELAY START_ADDR;
      end_addr <= #DELAY START_ADDR;
      app_en <= #DELAY `FALSE;
      dram_read <= #DELAY `FALSE;
      app_wdf_wren <= #DELAY `FALSE;
      app_wdf_end <= #DELAY `TRUE;
      tmp_data_offset <= #DELAY 0; //APP_DATA_WIDTH - XB_SIZE;
      dramifc_state <= #DELAY DRAMIFC_MSG_WAIT;
      
      //fds[0] <= #DELAY 0; fds[1] <= #DELAY 0;

      patch_conf_valid <= #DELAY `FALSE;
      patch_conf <= #DELAY 0;
      for(i=0; i < PATCH_SIZE; i=i+1) row_conf_valid[i] <= #DELAY `FALSE;
      row_conf <= #DELAY 0;
      
      for(i=0; i < PATCH_SIZE; i=i+1) begin
        init_a_reducer[i] <= #DELAY `FALSE;
        for(j=0; j < N_ROW_REDUCER; j=j+1)
          init_the_reducer[i][j] <= #DELAY `FALSE;
        a_reducer_done[i] <= #DELAY `FALSE;
      end//for(i)

      fpga_msg_valid <= #DELAY `FALSE;
      fpga_msg <= #DELAY 0;

      n_row <= #DELAY 0; l_col <= #DELAY 0; n_frame <= #DELAY 0;
      pixel_state <= #DELAY PIXEL_STANDBY;
      //for(i=0; i < PATCH_SIZE; i=i+1) coeffrd_state[i] <= #DELAY COEFFRD_OK;

      result_patch_num <= #DELAY 0;
      result_patch_sum <= #DELAY 0;
    end else begin // normal operation
      xb2pixel_wren <= #DELAY !xb2pixel_full && pc_msg_pending &&  pc_msg_is_ds;
      xb2dram_wren  <= #DELAY !xb2dram_full  && pc_msg_pending && !pc_msg_is_ds;

      //fds[0] <= #DELAY pixel_msg[(XB_SIZE+12)+:FP_SIZE];
      //fds[1] <= #DELAY pixel_msg[12+:FP_SIZE];//Note: throw away the 4 LSB

      //Note: always write into FIFO when there is valid DRAM data because
      //flow control is done upstream by DRAMIfc
      patch_conf_valid <= #DELAY app_rd_data_valid
                       && app_rd_data[0] == `FALSE; //This is a patch_coeff
      for(i=0; i < PATCH_SIZE; i=i+1)
        row_conf_valid[i] <= #DELAY app_rd_data_valid
                      && app_rd_data[0] == `TRUE //This is a row reducer coeff
                      && app_rd_data[7:4] == i;//This is my row
      patch_conf <= #DELAY app_rd_data[4+:PATCH_CONF_SIZE];
      row_conf   <= #DELAY app_rd_data[8+:ROW_REDUCER_CONFIG_SIZE];

      init_a_reducer[0] <= #DELAY !patch_coeff_fifo_empty
        && !row_coeff_fifo_empty[0] && |the_reducer_avail[0];
      for(j=0; j < N_ROW_REDUCER; j=j+1)
        init_the_reducer[0][j] <= #DELAY
          j == avail_reducer_idx[0] && the_reducer_avail[0][j]
          && !patch_coeff_fifo_empty && !row_coeff_fifo_empty[0];
      for(i=1; i < PATCH_SIZE; i=i+1) begin
        init_a_reducer[i] <= #DELAY !interline_fifo_empty[i]
                          && !row_coeff_fifo_empty[i] && |the_reducer_avail[i];
        for(j=0; j < N_ROW_REDUCER; j=j+1)
          init_the_reducer[i][j] <= #DELAY
            j == avail_reducer_idx[i] && the_reducer_avail[i][j]
            && !interline_fifo_empty[i] && !row_coeff_fifo_empty[i];

        // This assumes that 2 reducers will not be done in the same clock cycle
        interline_sum_in[i] <= #DELAY
            the_reducer_done[i-1][0] ? reducer_sum[i-1][0]
          : the_reducer_done[i-1][1] ? reducer_sum[i-1][1]
          : the_reducer_done[i-1][2] ? reducer_sum[i-1][2]
          /*: the_reducer_done[i-1][3] ? reducer_sum[i-1][3]
          : the_reducer_done[i-1][4] ? reducer_sum[i-1][4]
          : the_reducer_done[i-1][5] ? reducer_sum[i-1][5]
          : the_reducer_done[i-1][6] ? reducer_sum[i-1][6]
          : the_reducer_done[i-1][7] ? reducer_sum[i-1][7]
          : the_reducer_done[i-1][8] ? reducer_sum[i-1][8]
          : the_reducer_done[i-1][9] ? reducer_sum[i-1][9]
          : the_reducer_done[i-1][10] ? reducer_sum[i-1][10]
          : the_reducer_done[i-1][11] ? reducer_sum[i-1][11]
          : the_reducer_done[i-1][12] ? reducer_sum[i-1][12]*/
          :                             reducer_sum[i-1][N_ROW_REDUCER-1];
        interline_num_in[i] <= #DELAY
            the_reducer_done[i-1][0] ? reducer_num[i-1][0]
          : the_reducer_done[i-1][1] ? reducer_num[i-1][1]
          : the_reducer_done[i-1][2] ? reducer_num[i-1][2]
          /*: the_reducer_done[i-1][3] ? reducer_num[i-1][3]
          : the_reducer_done[i-1][4] ? reducer_num[i-1][4]
          : the_reducer_done[i-1][5] ? reducer_num[i-1][5]
          : the_reducer_done[i-1][6] ? reducer_num[i-1][6]
          : the_reducer_done[i-1][7] ? reducer_num[i-1][7]
          : the_reducer_done[i-1][8] ? reducer_num[i-1][8]
          : the_reducer_done[i-1][9] ? reducer_num[i-1][9]
          : the_reducer_done[i-1][10] ? reducer_num[i-1][10]
          : the_reducer_done[i-1][11] ? reducer_num[i-1][11]
          : the_reducer_done[i-1][12] ? reducer_num[i-1][12]*/
          :                             reducer_num[i-1][N_ROW_REDUCER-1];
        interline_row_in[i] <= #DELAY
           (the_reducer_done[i-1][0] ? reducer_row[i-1][0]
          : the_reducer_done[i-1][1] ? reducer_row[i-1][1]
          : the_reducer_done[i-1][2] ? reducer_row[i-1][2]
          /*: the_reducer_done[i-1][3] ? reducer_row[i-1][3]
          : the_reducer_done[i-1][4] ? reducer_row[i-1][4]
          : the_reducer_done[i-1][5] ? reducer_row[i-1][5]
          : the_reducer_done[i-1][6] ? reducer_row[i-1][6]
          : the_reducer_done[i-1][7] ? reducer_row[i-1][7]
          : the_reducer_done[i-1][8] ? reducer_row[i-1][8]
          : the_reducer_done[i-1][9] ? reducer_row[i-1][9]
          : the_reducer_done[i-1][10] ? reducer_row[i-1][10]
          : the_reducer_done[i-1][11] ? reducer_row[i-1][11]
          : the_reducer_done[i-1][12] ? reducer_row[i-1][12]*/
          :                        reducer_row[i-1][N_ROW_REDUCER-1]) + `TRUE;
        interline_col_in[i] <= #DELAY
            the_reducer_done[i-1][0] ? reducer_col[i-1][0]
          : the_reducer_done[i-1][1] ? reducer_col[i-1][1]
          : the_reducer_done[i-1][2] ? reducer_col[i-1][2]
          /*: the_reducer_done[i-1][3] ? reducer_col[i-1][3]
          : the_reducer_done[i-1][4] ? reducer_col[i-1][4]
          : the_reducer_done[i-1][5] ? reducer_col[i-1][5]
          : the_reducer_done[i-1][6] ? reducer_col[i-1][6]
          : the_reducer_done[i-1][7] ? reducer_col[i-1][7]
          : the_reducer_done[i-1][8] ? reducer_col[i-1][8]
          : the_reducer_done[i-1][9] ? reducer_col[i-1][9]
          : the_reducer_done[i-1][10] ? reducer_col[i-1][10]
          : the_reducer_done[i-1][11] ? reducer_col[i-1][11]
          : the_reducer_done[i-1][12] ? reducer_col[i-1][12]*/
          :                             reducer_col[i-1][N_ROW_REDUCER-1];
      end//for(i)

      for(i=0; i < PATCH_SIZE; i=i+1)
        a_reducer_done[i] <= #DELAY (|the_reducer_done[i]);

      // Pick up the result from the last row
      // TODO: use a_reducer_done[PATCH_SIZE-1] to drive output from weighted
      // summer
      result_patch_sum <= #DELAY
          the_reducer_done[PATCH_SIZE-1][0] ? reducer_sum[PATCH_SIZE-1][0]
        : the_reducer_done[PATCH_SIZE-1][1] ? reducer_sum[PATCH_SIZE-1][1]
        : the_reducer_done[PATCH_SIZE-1][2] ? reducer_sum[PATCH_SIZE-1][2]
        /*: the_reducer_done[PATCH_SIZE-1][3] ? reducer_sum[PATCH_SIZE-1][3]
        : the_reducer_done[PATCH_SIZE-1][4] ? reducer_sum[PATCH_SIZE-1][4]
        : the_reducer_done[PATCH_SIZE-1][5] ? reducer_sum[PATCH_SIZE-1][5]
        : the_reducer_done[PATCH_SIZE-1][6] ? reducer_sum[PATCH_SIZE-1][6]
        : the_reducer_done[PATCH_SIZE-1][7] ? reducer_sum[PATCH_SIZE-1][7]
        : the_reducer_done[PATCH_SIZE-1][8] ? reducer_sum[PATCH_SIZE-1][8]
        : the_reducer_done[PATCH_SIZE-1][9] ? reducer_sum[PATCH_SIZE-1][9]
        : the_reducer_done[PATCH_SIZE-1][10] ? reducer_sum[PATCH_SIZE-1][10]
        : the_reducer_done[PATCH_SIZE-1][11] ? reducer_sum[PATCH_SIZE-1][11]
        : the_reducer_done[PATCH_SIZE-1][12] ? reducer_sum[PATCH_SIZE-1][12]*/
        :                         reducer_sum[PATCH_SIZE-1][N_ROW_REDUCER-1];
      result_patch_num <= #DELAY
          the_reducer_done[PATCH_SIZE-1][0] ? reducer_num[PATCH_SIZE-1][0]
        : the_reducer_done[PATCH_SIZE-1][1] ? reducer_num[PATCH_SIZE-1][1]
        : the_reducer_done[PATCH_SIZE-1][2] ? reducer_num[PATCH_SIZE-1][2]
        /*: the_reducer_done[PATCH_SIZE-1][3] ? reducer_num[PATCH_SIZE-1][3]
        : the_reducer_done[PATCH_SIZE-1][4] ? reducer_num[PATCH_SIZE-1][4]
        : the_reducer_done[PATCH_SIZE-1][5] ? reducer_num[PATCH_SIZE-1][5]
        : the_reducer_done[PATCH_SIZE-1][6] ? reducer_num[PATCH_SIZE-1][6]
        : the_reducer_done[PATCH_SIZE-1][7] ? reducer_num[PATCH_SIZE-1][7]
        : the_reducer_done[PATCH_SIZE-1][8] ? reducer_num[PATCH_SIZE-1][8]
        : the_reducer_done[PATCH_SIZE-1][9] ? reducer_num[PATCH_SIZE-1][9]
        : the_reducer_done[PATCH_SIZE-1][10] ? reducer_num[PATCH_SIZE-1][10]
        : the_reducer_done[PATCH_SIZE-1][11] ? reducer_num[PATCH_SIZE-1][11]
        : the_reducer_done[PATCH_SIZE-1][12] ? reducer_num[PATCH_SIZE-1][12]*/
        :                         reducer_num[PATCH_SIZE-1][N_ROW_REDUCER-1];

      //pc_msg_pending_d <= #DELAY pc_msg_pending;
      // Note how the delay through a sequential logic syncs up with pc_msg_d
      //pc_msg_is_ds_d <= #DELAY pc_msg_is_ds;
      if(pc_msg_ack) begin// Was this a real message?
        pc_msg_d <= #DELAY pc_msg;// delay this to match up against pc_msg_is_ds_d
        if(!pc_msg_is_ds) n_pc_dram_msg <= #DELAY n_pc_dram_msg + `TRUE;
      end

      // For testing over xillybus
      //fpga_msg_valid <= #DELAY app_en && dram_read;
      //fpga_msg <= #DELAY {`FALSE, app_addr, `FALSE, dramifc_state};
      //fpga_msg_valid <= #DELAY app_rd_data_valid;
      //fpga_msg <= #DELAY app_rd_data[0+:XB_SIZE];
      
      // Data always flows (fdn and fds is always available);
      // the question is whether it is valid
      pval_d <= #DELAY xb2pixel_ack;
      fval_d <= #DELAY fval;
      lval_d <= #DELAY lval;

      // A delay to sync up the floating point logic output with delayed pval
      //fds_val_d <= #DELAY fds_val;
      //fds_d <= #DELAY fds;

      if(|interline_fifo_overflow) pixel_state <= #DELAY PIXEL_ERROR;
      else if(!xb2pixel_empty)
       case(pixel_state)
         PIXEL_STANDBY:
           if(!fval) begin
             n_row <= #DELAY 0; l_col <= #DELAY 0; n_frame <= #DELAY 0;
             pixel_state <= #DELAY PIXEL_INTERFRAME;
           end
         PIXEL_INTRALINE:
           if(lval) l_col <= #DELAY l_col + N_PIXEL_PER_CLK;
           else begin
             if(fval) begin
               n_row <= #DELAY n_row + 1'b1;
               pixel_state <= #DELAY PIXEL_INTERLINE;
             end else begin
               n_frame <= #DELAY n_frame + 1'b1;
               pixel_state <= #DELAY PIXEL_INTERFRAME;
             end
           end
         PIXEL_INTERLINE:
           if(lval) begin
              l_col <= #DELAY 0;
              pixel_state <= #DELAY PIXEL_INTRALINE;
            end
          PIXEL_INTERFRAME:
            if(lval) begin
              n_row <= #DELAY 0; l_col <= #DELAY 0;
              pixel_state <= #DELAY PIXEL_INTRALINE;
            end
          default: begin
          end
        endcase

      case(dramifc_state)
        DRAMIFC_ERROR: begin
        end
        DRAMIFC_MSG_WAIT: begin
          if(!xb2dram_empty) begin
            //fpga_msg_valid <= #DELAY `TRUE;
            //fpga_msg <= #DELAY dram_msg;//debug unintentional end of coeff

            tmp_data[tmp_data_offset+:XB_SIZE] <= #DELAY dram_msg;
            // Is this the last of the tmp_data I was waiting for?
            if(tmp_data_offset == (2*APP_DATA_WIDTH - XB_SIZE)) begin
              app_en <= #DELAY `TRUE;
              //end_addr <= #DELAY end_addr + ADDR_INC;
              dramifc_state <= #DELAY DRAMIFC_WR_WAIT;
            end
            tmp_data_offset <= #DELAY tmp_data_offset + XB_SIZE;
          end
        end
        DRAMIFC_WR_WAIT:
          if(app_rdy && app_wdf_rdy) begin
            //fpga_msg_valid <= #DELAY `TRUE;
            //fpga_msg <= #DELAY dram_msg;//debug unintentional end of coeff

            app_addr <= #DELAY app_addr + ADDR_INC; // for next write
            app_en <= #DELAY `FALSE;
            app_wdf_data <= #DELAY tmp_data[0+:APP_DATA_WIDTH];
            app_wdf_wren <= #DELAY `TRUE; //fpga_msg_valid <= #DELAY `TRUE;
            fpga_msg <= #DELAY tmp_data[0+:XB_SIZE];
            app_wdf_end <= #DELAY `FALSE;
            dramifc_state <= #DELAY DRAMIFC_WR1;
          end
        DRAMIFC_WR1:
          if(app_wdf_rdy) begin
            //fpga_msg_valid <= #DELAY `TRUE;
            //fpga_msg <= #DELAY dram_msg;//debug unintentional end of coeff

            app_wdf_data <= #DELAY tmp_data[APP_DATA_WIDTH+:APP_DATA_WIDTH];
            app_wdf_end <= #DELAY `TRUE; //fpga_msg_valid <= #DELAY `TRUE;
            //fpga_msg <= #DELAY tmp_data[APP_DATA_WIDTH+:XB_SIZE];
            dramifc_state <= #DELAY DRAMIFC_WR2;
          end
        DRAMIFC_WR2: begin
          //fpga_msg_valid <= #DELAY `TRUE;
          //fpga_msg <= #DELAY dram_msg;//debug unintentional end of coeff

          app_en <= #DELAY `FALSE;
          app_wdf_wren <= #DELAY `FALSE;
          tmp_data_offset <= #DELAY 0;//APP_DATA_WIDTH - XB_SIZE;
          // Am I writing the end of coefficient?
          if(app_wdf_data[1:0] == 2'b01) begin
            end_addr <= #DELAY app_addr - ADDR_INC;
            app_addr <= #DELAY START_ADDR;
            dram_read <= #DELAY `TRUE;
            app_en <= #DELAY `TRUE;
            //fpga_msg_valid <= #DELAY `TRUE;
            //fpga_msg <= #DELAY dram_msg;//debug unintentional end of coeff
            dramifc_state <= #DELAY DRAMIFC_READING;
          end else
            dramifc_state <= #DELAY app_wdf_rdy ? DRAMIFC_MSG_WAIT : DRAMIFC_ERROR;
        end
        DRAMIFC_READING: begin
          if(dramifc_overflow) begin
            //invariance assertion
            app_en <= #DELAY `FALSE;
            dramifc_state <= #DELAY DRAMIFC_ERROR;
          end else begin
            if(app_rdy) app_addr <= #DELAY app_addr + ADDR_INC;
            if(app_addr == end_addr) begin
              app_en <= #DELAY `FALSE;
              dramifc_state <= #DELAY DRAMIFC_INTERFRAME;
            end else if(patch_coeff_fifo_high || row_coeff_fifo_high) begin
              app_en <= #DELAY `FALSE;//Note: the address is already incremented
              dramifc_state <= #DELAY DRAMIFC_THROTTLED;
            end
          end
        end
        DRAMIFC_THROTTLED:
          if(app_rd_data_valid && dramifc_overflow) begin
            //invariance assertion
            dramifc_state <= #DELAY DRAMIFC_ERROR;
          end else if(!patch_coeff_fifo_high && !row_coeff_fifo_high) begin
            app_en <= #DELAY `TRUE;
            dramifc_state <= #DELAY DRAMIFC_READING;
          end
        DRAMIFC_INTERFRAME:
          if(!xb2pixel_empty && !fval) begin //Get ready for the next frame
            app_addr <= #DELAY START_ADDR;
            app_en <= #DELAY `TRUE;
            dramifc_state <= #DELAY DRAMIFC_READING;
          end
      endcase//dramifc_state
    end//!RESET

endmodule
