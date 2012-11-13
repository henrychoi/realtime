`timescale 1ps/1ps
module application#(parameter SIMULATION=0, DELAY=1
, XB_SIZE=1,ADDR_WIDTH=1, APP_DATA_WIDTH=1)
(input RESET, CLK, output error, output[7:4] GPIO_LED
, output reg app_done
, input app_rdy, output reg app_en, output reg dram_read
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
, input pc_msg_pending, output pc_msg_ack, input[XB_SIZE-1:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[APP_DATA_WIDTH-1:0] fpga_msg
);
`include "function.v"
  integer i;
  localparam HB_CTR_SIZE = 16;
  reg[HB_CTR_SIZE-1:0] hb_ctr;

  reg[3:0] n_pc_dram_msg;// = 2 * 256/32
  
  wire pc_msg_is_ds;
  reg pc_msg_is_ds_d, pc_msg_pending_d;
  wire[XB_SIZE-1:0] dram_msg;
  wire[2*XB_SIZE-1:0] pixel_msg;
  reg[XB_SIZE-1:0] pc_msg_d;
  wire xb2pixel_full, xb2dram_full, xb2pixel_empty, xb2dram_empty
    , xb2pixel_ack, xb2dram_ack, xb2pixel_wren, xb2dram_wren;

  localparam PIXEL_ERROR = 0, PIXEL_STANDBY = 1, PIXEL_INTRALINE = 2
    , PIXEL_INTERLINE = 3, PIXEL_INTERFRAME = 4, N_PIXEL_STATE = 5;
  reg[log2(N_PIXEL_STATE)-1:0] pixel_state;

  localparam FP_SIZE=20
    , N_FRAME_SIZE = 20
    , N_COL_MAX = 2048, N_ROW_MAX = 2064 //2k rows + 8 dark pixels top and btm
    , PATCH_SIZE = 12//, PATCH_SIZE_MAX = 16
    , N_PATCH = 600000 //Can handle up to 1M
    , N_PIXEL_PER_CLK = 2'd2
    , N_ROW_REDUCER = 2;
  reg[N_FRAME_SIZE-1:0] n_frame;
  reg[log2(N_ROW_MAX)-1:0] n_row;//, n_row_d[N_FADD_LATENCY-1:0];
  reg[log2(N_COL_MAX)-1:0] l_col;//, n_col_d[N_FADD_LATENCY-1:0];
  //reg[0:0] init_reducer_d;
  wire[PATCH_SIZE-1:0] init_reducer, free_reducer;
  wire[N_ROW_REDUCER-1:0] reducer_avail[PATCH_SIZE-1:0]
                        , reducer_init[PATCH_SIZE-1:0]
                        , reducer_done[PATCH_SIZE-1:0];
  wire[log2(N_ROW_REDUCER)-1:0] avail_reducer[PATCH_SIZE-1:0];
  wire dramifc_overflow;
  wire[FP_SIZE-1:0] interline_sum_in[PATCH_SIZE-1:1]
                  , interline_sum_out[PATCH_SIZE-1:1]
                  , reducer_sum[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0]
                  , patch_sum; //The final answer
  wire[log2(N_PATCH)-1:0] conf_num
                        , interline_num_in[PATCH_SIZE-1:1]
                        , interline_num_out[PATCH_SIZE-1:1]
                        , reducer_num[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0]
                        , patch_num; //The ID of the final answer
  wire[log2(N_ROW_MAX)-1:0] conf_row
                          , interline_row_in[PATCH_SIZE-1:1]
                          , interline_row_out[PATCH_SIZE-1:1]
                          , reducer_row[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0];
  wire[log2(N_COL_MAX)-1:0] conf_col
                          , interline_col_in[PATCH_SIZE-1:1]
                          , interline_col_out[PATCH_SIZE-1:1]
                          , reducer_col[PATCH_SIZE-1:0][N_ROW_REDUCER-1:0];
  wire[PATCH_SIZE-1:1] interline_fifo_overflow, interline_fifo_empty;
  wire[PATCH_SIZE-1:0] row_coeff_fifo_overflow, row_coeff_fifo_high
                     , row_coeff_fifo_empty, row_coeff_fifo_full;
  wire patch_coeff_fifo_overflow, patch_coeff_fifo_high
     , patch_coeff_fifo_empty, patch_coeff_fifo_full;

  // Config variables
  localparam PATCH_COEFF_SIZE = 43
     , ROW_REDUCER_CONFIG_SIZE = PATCH_SIZE * FP_SIZE;
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
  localparam DRAMIFC_ERROR = 0
    , DRAMIFC_WR1 = 1, DRAMIFC_WR2 = 2, DRAMIFC_MSG_WAIT = 3
    , DRAMIFC_WR_WAIT = 4
    , DRAMIFC_READING = 5, DRAMIFC_THROTTLED = 6, DRAMIFC_INTERFRAME = 7
    , DRAMIFC_N_STATE = 8;
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
  assign GPIO_LED = {dramifc_state, error};
  //assign heartbeat = hb_ctr[HB_CTR_SIZE-1];
  assign pc_msg_ack = pc_msg_pending && !xb2pixel_full && !xb2dram_full;  
  assign {fval, lval} = pixel_msg[4+:2];
  assign fds[0] = pixel_msg[(XB_SIZE+12)+:FP_SIZE];//Note: throw away the 4 LSB
  assign fds[1] = pixel_msg[12+:FP_SIZE];//Note: throw away the 4 LSB
  // This works only if I ack the xb2pixel fifo as soon as it is !empty
  // Using combinational logic to ack FIFO is necessary for the FWFT feature
  assign xb2pixel_ack = !patch_coeff_fifo_empty && !row_coeff_fifo_empty
    && !xb2pixel_empty;
  assign xb2dram_ack = !xb2dram_empty
   && !(dramifc_state == DRAMIFC_WR1 || dramifc_state == DRAMIFC_WR2
        || dramifc_state == DRAMIFC_WR_WAIT);
  assign xb2pixel_wren = !xb2pixel_full && pc_msg_pending_d &&  pc_msg_is_ds_d;
  assign xb2dram_wren  = !xb2dram_full  && pc_msg_pending_d && !pc_msg_is_ds_d;
  assign pc_msg_is_ds = pc_msg[1:0] == 2'b00 && n_pc_dram_msg == 0;
  assign dramifc_overflow = patch_coeff_fifo_overflow || |row_coeff_fifo_overflow;

  // Builtin FIFO does NOT offer ALMOST_full port
  xb2dram xb2dram(.clk(CLK), .rst(RESET)
    , .din(pc_msg_d), .wr_en(xb2dram_wren)
    , .rd_en(xb2dram_ack), .dout(dram_msg)
    , .almost_full(xb2dram_full), .full(), .empty(xb2dram_empty)
    , .sbiterr(), .dbiterr());
  xb2pixel xb2pixel(.clk(CLK), .rst(RESET)
    , .din(pc_msg_d), .wr_en(xb2pixel_wren)
    , .rd_en(xb2pixel_ack), .dout(pixel_msg)
    , .almost_full(xb2pixel_full), .full(), .empty(xb2pixel_empty)
    , .sbiterr(), .dbiterr());
  
`ifdef PROCESS_PIXELS
  patch_coeff_fifo patch_fifo(//.wr_clk(CLK), .rd_clk(CLK)
    .clk(CLK), .rst(RESET)
    , .din(app_rd_data[4+:PATCH_COEFF_SIZE])
    //Note: always write into FIFO when there is valid DRAM data because
    //flow control is done upstream by DRAMIfc
    , .wr_en(app_rd_data_valid
             && app_rd_data[0] == `FALSE) //This is a patch_coeff
    , .rd_en(init_reducer[0])//, .valid(patch_fifo_val)
    //, .dout(patch_data)
    , .dout({conf_col, conf_row, conf_num})
    , .prog_full(patch_coeff_fifo_high), .full(patch_coeff_fifo_full)
    , .overflow(patch_coeff_fifo_overflow), .empty(patch_coeff_fifo_empty));

  assign init_reducer[0] = !patch_coeff_fifo_empty
    && !row_coeff_fifo_empty[0] && |reducer_avail[0];
      
  genvar geni, genj;
  generate
    for(geni=0; geni < PATCH_SIZE; geni=geni+1) begin: for_all_patch_rows
      // Note: I do not check whether the last reducer is actually available
      // (|reducer_avail[geni]) tells me if no reducer is available at all.
      assign avail_reducer[geni]
        = reducer_avail[geni][0] ? 0
        /*: reducer_avail[geni][1] ? 1
        : reducer_avail[geni][2] ? 2
        : reducer_avail[geni][3] ? 3
        : reducer_avail[geni][4] ? 4
        : reducer_avail[geni][5] ? 5
        : reducer_avail[geni][6] ? 6
        : reducer_avail[geni][7] ? 7*/
        :                          (N_ROW_REDUCER - 1);

      assign free_reducer[geni] = |reducer_done[geni];

      row_coeff_fifo row_coeff_fifo(.clk(CLK), .rst(RESET)
        //.wr_clk(CLK), .rd_clk(CLK)
        , .din(app_rd_data[8+:ROW_REDUCER_CONFIG_SIZE])
        //Note: always write into FIFO when there is valid DRAM data because
        //flow control done upstream by DRAMIfc
        , .wr_en(app_rd_data_valid
                 && app_rd_data[0] == `TRUE   //This is a row reducer coeff
                 && app_rd_data[7:4] == geni) //This is my row
        , .rd_en(init_reducer[geni])
        , .dout(conf_weights[geni])
        , .prog_full(row_coeff_fifo_high[geni])
        , .full(row_coeff_fifo_full[geni])
        , .overflow(row_coeff_fifo_overflow[geni])
        , .empty(row_coeff_fifo_empty[geni]));

      for(genj=0; genj < N_ROW_REDUCER; genj=genj+1) begin: assign_reducer_init
        //Tell the chosen reducer to initialize
        assign reducer_init[geni][genj] = init_reducer[geni]
          && genj == avail_reducer[geni];
      end
    end//for geni

    for(genj=0; genj < N_ROW_REDUCER; genj=genj+1) begin: init_1st_row_reducer
      PatchRowReducer#(.N_PATCH(N_PATCH), .PATCH_SIZE(PATCH_SIZE)
          , .FP_SIZE(FP_SIZE), .N_PIXEL_PER_CLK(N_PIXEL_PER_CLK)
          , .N_COL_SIZE(log2(N_COL_MAX)), .N_ROW_SIZE(log2(N_ROW_MAX)))
        fst_row_reducer(.clk(CLK), .RESET(RESET)
        , .available(reducer_avail[0][genj]), .init(reducer_init[0][genj])
        , .conf_row(conf_row), .conf_col(conf_col)
        //First row starts with the running sum = 0 of course
        , .conf_sum({FP_SIZE{`FALSE}}) 
        , .conf_num(conf_num), .conf_weights(conf_weights[0])
        , .cur_row(n_row), .l_col(l_col)
        , .fds_val_in(lval_d), .fds0(fds[0]), .fds1(fds[1])
        , .done(reducer_done[0][genj])
        , .num(reducer_num[0][genj]), .sum(reducer_sum[0][genj])
        , .matcher_row(reducer_row[0][genj])
        , .start_col(reducer_col[0][genj]));
    end//genj

    for(geni=1; geni < PATCH_SIZE; geni=geni+1) begin//: for_all_non_1st_rows
      interline_fifo interline_fifo(.clk(CLK), .rst(RESET)
        , .din({interline_num_in[geni], interline_row_in[geni]
              , interline_sum_in[geni], interline_col_in[geni]})
        //When a previous row's sum is ready, move that into the interline fifo
        , .wr_en(free_reducer[geni-1])
        , .rd_en(init_reducer[geni])
        , .dout({interline_num_out[geni], interline_row_out[geni]
               , interline_sum_out[geni], interline_col_out[geni]})
        , .full(), .overflow(interline_fifo_overflow[geni])
        , .empty(interline_fifo_empty[geni]));
      
      for(genj=0; genj < N_ROW_REDUCER; genj=genj+1) begin//: for_row_reducers_on_non_1st
        PatchRowReducer#(.N_PATCH(N_PATCH), .PATCH_SIZE(PATCH_SIZE)
            , .FP_SIZE(FP_SIZE), .N_PIXEL_PER_CLK(N_PIXEL_PER_CLK)
            , .N_COL_SIZE(log2(N_COL_MAX)), .N_ROW_SIZE(log2(N_ROW_MAX)))
          row_reducer(.clk(CLK), .RESET(RESET)
          , .available(reducer_avail[geni][genj]), .init(reducer_init[geni][genj])
          , .conf_row(interline_row_out[geni])
          , .conf_col(interline_col_out[geni])
          , .conf_sum(interline_sum_out[geni])
          , .conf_num(interline_num_out[geni])
          , .conf_weights(conf_weights[geni])
          , .cur_row(n_row), .l_col(l_col)
          , .fds_val_in(lval_d), .fds0(fds[0]), .fds1(fds[1])
          , .done(reducer_done[geni][genj])
          , .num(reducer_num[geni][genj]), .sum(reducer_sum[geni][genj])
          , .matcher_row(reducer_row[geni][genj])
          , .start_col(reducer_col[geni][genj]));
      end//for genj
      
      assign init_reducer[geni] = !interline_fifo_empty[geni]
        && !row_coeff_fifo_empty[geni] && |reducer_avail[geni];

      // This assumes that 2 reducers will not be done in the same clock cycle
      assign interline_sum_in[geni]
        = reducer_done[geni-1][0] ? reducer_sum[geni-1][0]
        /*: reducer_done[geni-1][1] ? reducer_sum[geni-1][1]
        : reducer_done[geni-1][2] ? reducer_sum[geni-1][2]
        : reducer_done[geni-1][3] ? reducer_sum[geni-1][3]
        : reducer_done[geni-1][4] ? reducer_sum[geni-1][4]
        : reducer_done[geni-1][5] ? reducer_sum[geni-1][5]
        : reducer_done[geni-1][6] ? reducer_sum[geni-1][6]
        : reducer_done[geni-1][7] ? reducer_sum[geni-1][7]*/
        :                           reducer_sum[geni-1][N_ROW_REDUCER-1];

      assign interline_num_in[geni]
        = reducer_done[geni-1][0] ? reducer_num[geni-1][0]
        /*: reducer_done[geni-1][1] ? reducer_num[geni-1][1]
        : reducer_done[geni-1][2] ? reducer_num[geni-1][2]
        : reducer_done[geni-1][3] ? reducer_num[geni-1][3]
        : reducer_done[geni-1][4] ? reducer_num[geni-1][4]
        : reducer_done[geni-1][5] ? reducer_num[geni-1][5]
        : reducer_done[geni-1][6] ? reducer_num[geni-1][6]
        : reducer_done[geni-1][7] ? reducer_num[geni-1][7]*/
        :                           reducer_num[geni-1][N_ROW_REDUCER-1];

      assign interline_row_in[geni]
       = (reducer_done[geni-1][0] ? reducer_row[geni-1][0]
        /*: reducer_done[geni-1][1] ? reducer_row[geni-1][1]
        : reducer_done[geni-1][2] ? reducer_row[geni-1][2]
        : reducer_done[geni-1][3] ? reducer_row[geni-1][3]
        : reducer_done[geni-1][4] ? reducer_row[geni-1][4]
        : reducer_done[geni-1][5] ? reducer_row[geni-1][5]
        : reducer_done[geni-1][6] ? reducer_row[geni-1][6]
        : reducer_done[geni-1][7] ? reducer_row[geni-1][7]*/
        :             reducer_row[geni-1][N_ROW_REDUCER-1]) + `TRUE;

      assign interline_col_in[geni]
        = reducer_done[geni-1][0] ? reducer_col[geni-1][0]
        /*: reducer_done[geni-1][1] ? reducer_col[geni-1][1]
        : reducer_done[geni-1][2] ? reducer_col[geni-1][2]
        : reducer_done[geni-1][3] ? reducer_col[geni-1][3]
        : reducer_done[geni-1][4] ? reducer_col[geni-1][4]
        : reducer_done[geni-1][5] ? reducer_col[geni-1][5]
        : reducer_done[geni-1][6] ? reducer_col[geni-1][6]
        : reducer_done[geni-1][7] ? reducer_col[geni-1][7]*/
        :             reducer_col[geni-1][N_ROW_REDUCER-1];
    end//for geni

    assign patch_sum
      = reducer_done[geni-1][0] ? reducer_sum[geni-1][0]
      /*: reducer_done[geni-1][1] ? reducer_sum[geni-1][1]
      : reducer_done[geni-1][2] ? reducer_sum[geni-1][2]
      : reducer_done[geni-1][3] ? reducer_sum[geni-1][3]
      : reducer_done[geni-1][4] ? reducer_sum[geni-1][4]
      : reducer_done[geni-1][5] ? reducer_sum[geni-1][5]
      : reducer_done[geni-1][6] ? reducer_sum[geni-1][6]
      : reducer_done[geni-1][7] ? reducer_sum[geni-1][7]*/
      : reducer_sum[geni-1][N_ROW_REDUCER-1];

    assign patch_num
      = reducer_done[geni-1][0] ? reducer_num[geni-1][0]
      /*: reducer_done[geni-1][1] ? reducer_num[geni-1][1]
      : reducer_done[geni-1][2] ? reducer_num[geni-1][2]
      : reducer_done[geni-1][3] ? reducer_num[geni-1][3]
      : reducer_done[geni-1][4] ? reducer_num[geni-1][4]
      : reducer_done[geni-1][5] ? reducer_num[geni-1][5]
      : reducer_done[geni-1][6] ? reducer_num[geni-1][6]
      : reducer_done[geni-1][7] ? reducer_num[geni-1][7]*/
      :             reducer_num[geni-1][N_ROW_REDUCER-1];
  endgenerate
`endif
  
  always @(posedge RESET, posedge fds_val)
    if(RESET) hb_ctr <= #DELAY 0;
    else hb_ctr <= #DELAY hb_ctr + `TRUE;

  always @(posedge CLK)
    if(RESET) begin
      n_pc_dram_msg <= #DELAY 0;
      pc_msg_pending_d <= #DELAY `FALSE;
  		app_addr <= #DELAY START_ADDR;
      end_addr <= #DELAY START_ADDR;
      app_en <= #DELAY `FALSE;
      dram_read <= #DELAY `FALSE;
      app_wdf_wren <= #DELAY `FALSE;
      app_wdf_end <= #DELAY `TRUE;
      tmp_data_offset <= #DELAY 0; //APP_DATA_WIDTH - XB_SIZE;
      dramifc_state <= #DELAY DRAMIFC_MSG_WAIT;
      
      fpga_msg_valid <= #DELAY `FALSE;
      fpga_msg <= #DELAY 0;

      pixel_state <= #DELAY PIXEL_STANDBY;
      //for(i=0; i < PATCH_SIZE; i=i+1) coeffrd_state[i] <= #DELAY COEFFRD_OK;
    end else begin // normal operation
      pc_msg_pending_d <= #DELAY pc_msg_pending;
      // Note how the delay through a sequential logic syncs up with pc_msg_d
      pc_msg_is_ds_d <= #DELAY pc_msg_is_ds;
      if(pc_msg_ack) begin// Was this a real message?
        pc_msg_d <= #DELAY pc_msg;// delay this to match up against pc_msg_is_ds_d
        if(!pc_msg_is_ds) n_pc_dram_msg <= #DELAY n_pc_dram_msg + `TRUE;
      end

      // For testing over xillybus
      fpga_msg_valid <= #DELAY app_rd_data_valid;
      fpga_msg <= #DELAY app_rd_data;
      
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
            tmp_data[tmp_data_offset+:XB_SIZE] <= #DELAY dram_msg;
            // Is this the last of the tmp_data I was waiting for?
            if(tmp_data_offset == (2*APP_DATA_WIDTH - XB_SIZE)) begin
              app_en <= #DELAY `TRUE;
              end_addr <= #DELAY end_addr + ADDR_INC;
              dramifc_state <= #DELAY DRAMIFC_WR_WAIT;
            end
            tmp_data_offset <= #DELAY tmp_data_offset + XB_SIZE;
          end
        end
        DRAMIFC_WR_WAIT:
          if(app_rdy && app_wdf_rdy) begin
            app_addr <= #DELAY app_addr + ADDR_INC; // for next write
            app_en <= #DELAY `FALSE;
            app_wdf_data <= #DELAY tmp_data[0+:APP_DATA_WIDTH];
            app_wdf_wren <= #DELAY `TRUE;
            app_wdf_end <= #DELAY `FALSE;
            dramifc_state <= #DELAY DRAMIFC_WR1;
          end
        DRAMIFC_WR1:
          if(app_wdf_rdy) begin
            app_wdf_end <= #DELAY `TRUE;
            app_wdf_data <= #DELAY tmp_data[APP_DATA_WIDTH+:APP_DATA_WIDTH];
            dramifc_state <= #DELAY DRAMIFC_WR2;
          end
        DRAMIFC_WR2: begin
          app_en <= #DELAY `FALSE;
          app_wdf_wren <= #DELAY `FALSE;
          tmp_data_offset <= #DELAY 0;//APP_DATA_WIDTH - XB_SIZE;
          // Does the data I am writing mark the end of the coefficients?
          if(dram_msg[1:0] == 2'b01) begin
            app_addr <= #DELAY START_ADDR;
            dram_read <= #DELAY `TRUE;
            app_en <= #DELAY `TRUE;
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
      endcase
    end

endmodule
