module application#(parameter DELAY=1, XB_SIZE=32, RAM_DATA_SIZE=1)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output pc_msg_ack
, output reg downstream_wren, output reg [2*XB_SIZE-1:0] downstream_din
, input downstream_high, downstream_overflow
, output app_running, app_error);
`include "function.v"
  localparam N_ZMW_SIZE = log2(4 * 1024 * 1024);
  localparam RAM_HEADER_SIZE = 8, ZMW_DATA_SIZE = RAM_DATA_SIZE - RAM_HEADER_SIZE
           , FP_SIZE = 32, DYE_SIZE = 2, N_DYE = 2**DYE_SIZE
           , INTENSITY_INDEX_SIZE = 2
           , MAX_STRIDE = 2**8 - 1, MAX_CLOCK_PER_FRAME = 2**24 - 1
           , MAX_FRAME = 2**24 - 1;
  reg [log2(MAX_STRIDE)-1:0] max_stride, n_stride;
  reg [log2(MAX_CLOCK_PER_FRAME)-1:0] clock_per_frame, n_clock
                                    , n_clock_throttled;
  reg [log2(MAX_FRAME)-1:0] max_frame, n_frame;
  wire[log2(MAX_FRAME):0] n_frame_1;//n_frame - 1, so could be -1
  assign n_frame_1 = n_frame - 1;
  reg [FP_SIZE-1:0] exposure;
  
  localparam MSG_ASSEMBLER_ERROR = 0, MSG_ASSEMBLER_WAIT1 = 1
           , MSG_ASSEMBLER_WAIT2 = 2, MSG_ASSEMBLER_WAIT3 = 3
           , MSG_ASSEMBLER_N_STATE = 4;
  reg [log2(MSG_ASSEMBLER_N_STATE)-1:0] msg_assembler_state;
  reg [2*XB_SIZE-1:0] msg_assembler_cache;
  reg [3*XB_SIZE-1:0] whole_pc_msg;
  reg whole_pc_msg_valid;

  localparam PACER_ERROR = 0, PACER_STOPPED = 1, PACER_STOPPING = 2
           , PACER_STARTING = 3, PACER_INIT = 4, PACER_INIT_THROTTLED = 5
           , PACER_STARTING_FRAME = 6, PACER_FRAME = 7
           , PACER_FRAME_THROTTLED = 8, PACER_STOPPING_FRAME = 9
           , PACER_INTERFRAME = 10, PACER_N_STATE = 11;
  reg [log2(PACER_N_STATE)-1:0] pacer_state;
  assign #DELAY app_running = pacer_state >= PACER_STARTING_FRAME;
  assign #DELAY app_error = !pacer_state; 
  assign #DELAY GPIO_LED = {pacer_state};
  
  localparam RAM_ERROR = 0, RAM_IDLE = 1
           , RAM_MSG_WAIT1 = 2, RAM_MSG_WAIT2 = 3, RAM_WR_WAIT = 4
           , RAM_WR1 = 5, RAM_WR2 = 6, RAM_READING = 7, RAM_THROTTLED = 8
           , RAM_N_STATE = 9;
  reg [log2(RAM_N_STATE)-1:0] ram_state[1:0];
  
  localparam N_ZMW = 128, BRAM_READ_LATENCY = 3;

  //simulate DRAM interface until we build our own board
  localparam RAM_ADDR_INCR = `TRUE; //my way of saying 1 while avoiding warning
  wire[1:0] ram_rdy, ram_wdf_rdy;
  reg [1:0] ram_en, ram_read, ram_wdf_wren, ram_wdf_end
          , ram_en_and_read[BRAM_READ_LATENCY-2:0], ram_rd_data_valid;
  assign ram_rdy = {`TRUE, `TRUE};
  assign ram_wdf_rdy = {`TRUE, `TRUE};
  
  localparam FADD_LATENCY = 11, FCOMP_LATENCY = 2
    , PULSE_EXPIRATION_DETERMINATION_LATENCY = FADD_LATENCY + FCOMP_LATENCY;

  reg [log2(N_ZMW)-1:0] ram_addr[1:0], wr_zmw, rd_zmw;
  //reg [1:0] ram_wren;
  wire[RAM_DATA_SIZE-1:0] ram_rd_data[1:0], to_ram_fifo_dout[1:0];
  reg [RAM_DATA_SIZE-1:0] to_ram_cache[1:0], ram_wdf_data;
  reg [RAM_HEADER_SIZE-1:0] to_ram_fifo_header[1:0];
  reg [ZMW_DATA_SIZE-1:0]   to_ram_fifo_data;
  reg[1:0] to_ram_fifo_wren;
  wire[1:0] to_ram_fifo_ack //Need Karnaugh logic for ACK, arrrg!
          , to_ram_fifo_full, to_ram_fifo_almost_full, to_ram_fifo_high
          , to_ram_fifo_empty, to_ram_fifo_almost_empty, to_ram_fifo_valid;
  assign #DELAY to_ram_fifo_valid = {!to_ram_fifo_empty[1], !to_ram_fifo_empty[0]};

  wire from_ram_fifo_ack, from_ram_fifo_empty, from_ram_fifo_valid
     , from_ram_fifo_high, from_ram_fifo_full, from_ram_fifo_almost_full;
  wire[RAM_HEADER_SIZE-1:0] from_ram_fifo_header;
  // register the inputs for timing margin
  reg  from_ram_src, from_ram_fifo_wren;
  reg [RAM_DATA_SIZE-1:0] from_ram_fifo_din;

  reg gTime_cal_en;
  wire fn_frame_rdy, nframeXexp_rdy, fn_frame_1_rdy;
  wire[FP_SIZE-1:0] fn_frame, nframeXexp, fn_frame_1, nframe_1Xexp;
  reg [FP_SIZE-1:0] gTime, gTime_exposure;
  
  i25tof nframe_to_f(.clk(CLK), .sclr(RESET)
                   , .a({`FALSE, n_frame}) //n_frame >= 0; sign bit always 0
                   , .operation_nd(gTime_cal_en)
                   , .result(fn_frame), .rdy(fn_frame_rdy));
  fmult fnframeXexp(.clk(CLK), .sclr(RESET)
                  , .a(fn_frame), .b(exposure), .operation_nd(fn_frame_rdy)
                  , .result(nframeXexp), .rdy(nframeXexp_rdy));

  i25tof nframe_1_to_f(.clk(CLK), .sclr(RESET)
                     , .a(n_frame_1), .operation_nd(gTime_cal_en)
                     , .result(fn_frame_1), .rdy(fn_frame_1_rdy));
  fmult fnframe_1Xexp(.clk(CLK), .sclr(RESET)
                    , .a(fn_frame_1), .b(exposure), .operation_nd(fn_frame_1_rdy)
                    , .result(nframe_1Xexp), .rdy(nframe_1Xexp_rdy));

  localparam MAX_PULSE_PER_ZMW = 3;
  wire[FP_SIZE-1:0] current_pulse_t1[MAX_PULSE_PER_ZMW-1:0]
                  , current_pulse_t1_d[MAX_PULSE_PER_ZMW-1:0]
                  , current_pulse_dt[MAX_PULSE_PER_ZMW-1:0]
                  , current_pulse_dt_d[MAX_PULSE_PER_ZMW-1:0]
                  , current_pulse_tf[MAX_PULSE_PER_ZMW-1:0];
  wire[MAX_PULSE_PER_ZMW-1:0] current_pulse_tf_rdy
     , gTimeGTEcurrent_pulse_tf, gTimeGTEcurrent_pulse_tf_rdy
     , updater_d_fifo_full, updater_d_fifo_empty
     , gTime_exposureGTEcurrent_pulse_t1, gTime_exposureGTEcurrent_pulse_t1_rdy
     , projection_duration_rdy, durationXintensity_rdy
     , intensity_d_fifo_empty;     
  wire updater_d_fifo_ack, dye_d_fifo_ack, xof_d, xof_dd
     , dye_d_fifo_empty, dye_d_fifo_full
     , zmwxof_d_fifo_ack, zmwxof_d_fifo_empty, zmwxof_d_fifo_full;
  reg [FCOMP_LATENCY-1:0] pulse_desc_valid_d;//delay of updater_d_fifo_ack
  wire[DYE_SIZE-1:0] current_pulse_dye[MAX_PULSE_PER_ZMW-1:0]
                   , current_pulse_dye_d[MAX_PULSE_PER_ZMW-1:0]
                   , pulse_dye[MAX_PULSE_PER_ZMW-1:0]
                   , pulse_dye_d[MAX_PULSE_PER_ZMW-1:0];
  wire[1:0] current_pulse_zz[1:0][MAX_PULSE_PER_ZMW-1:0];
  wire[INTENSITY_INDEX_SIZE-1:0] current_pulse_in_idx[MAX_PULSE_PER_ZMW-1:0]
                               , current_pulse_in_idx_d[MAX_PULSE_PER_ZMW-1:0];
  wire[9:0] current_pulse_10z;
  wire xof;//either SOF, EOF
  wire[N_ZMW_SIZE-1:0] current_pulse_zmw_number
                     , current_pulse_zmw_number_d[MAX_PULSE_PER_ZMW-1:0]
                     , pulse_intensity_zmw[MAX_PULSE_PER_ZMW-1:0]
                     , pulse_dye_zmw, pulse_dye_zmw_d
                     , strength2_zmw[N_DYE-1:0];
  reg [N_ZMW_SIZE-1:0] current_pulse_zmw_number_dd;
  reg [FP_SIZE-1:0] time1[MAX_PULSE_PER_ZMW-1:0]
    , time2_d[MAX_PULSE_PER_ZMW-1:0][FCOMP_LATENCY-1:0]
    , current_pulse_t1_dd[MAX_PULSE_PER_ZMW-1:0][FCOMP_LATENCY-1:0]
    , current_pulse_tf_d[MAX_PULSE_PER_ZMW-1:0][FCOMP_LATENCY-1:0];
  wire[FP_SIZE-1:0] projection_duration[MAX_PULSE_PER_ZMW-1:0]
                  , pulse_intensity[MAX_PULSE_PER_ZMW-1:0]
				          , durationXintensity[MAX_PULSE_PER_ZMW-1:0]
                  //4 possible dyes for each pulse possibility
                  , pulse_strength[MAX_PULSE_PER_ZMW-1:0][N_DYE-1:0]
                  , strength01[N_DYE-1:0], strength2_d[N_DYE-1:0]
                  , strength012[N_DYE-1:0];
  reg [FP_SIZE-1:0] pulse_intensity_pool[2**2-1:0]
                  , current_pulse_intensity[MAX_PULSE_PER_ZMW-1:0];
  wire[N_DYE-1:0] strength01_rdy, strength012_rdy;


  better_fifo#(.TYPE("FromRAM"), .WIDTH(RAM_DATA_SIZE), .DELAY(DELAY))
  from_ram_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
              , .wren(from_ram_fifo_wren), .din(from_ram_fifo_din)
              , .high(from_ram_fifo_high), .full(from_ram_fifo_full)
              , .almost_full(from_ram_fifo_almost_full)
              , .rden(from_ram_fifo_ack)
              , .dout({current_pulse_t1[0], current_pulse_dt[0]
                     , current_pulse_t1[1], current_pulse_dt[1]
                     , current_pulse_t1[2], current_pulse_dt[2]
                     , current_pulse_zz[0][0], current_pulse_dye[0]
                     , current_pulse_zz[1][0], current_pulse_in_idx[0]
                     , current_pulse_zz[0][1], current_pulse_dye[1]
                     , current_pulse_zz[1][1], current_pulse_in_idx[1]
                     , current_pulse_zz[0][2], current_pulse_dye[2]
                     , current_pulse_zz[1][2], current_pulse_in_idx[2]
                     , current_pulse_10z, current_pulse_zmw_number
                     , from_ram_fifo_header})
              , .empty(from_ram_fifo_empty), .almost_empty());
  assign from_ram_fifo_valid = !from_ram_fifo_empty;
  assign from_ram_fifo_ack = from_ram_fifo_valid //is there anything to ACK?
                          && !to_ram_fifo_full
                          && !updater_d_fifo_full[0];//chain to updater_d FIFO
  
  genvar geni, genj;
  generate
    for(geni=0; geni < MAX_PULSE_PER_ZMW; geni=geni+1) begin
      fadd t1Pdt(.clk(CLK), .sclr(RESET), .operation_nd(from_ram_fifo_valid)
               , .a(current_pulse_t1[geni]), .b(current_pulse_dt[geni])
               , .result(current_pulse_tf[geni])
               , .rdy(current_pulse_tf_rdy[geni]));

      fgte gTimeGTEtf(.clk(CLK), .sclr(RESET)
                    , .operation_nd(current_pulse_tf_rdy[geni])
                    , .a(gTime), .b(current_pulse_tf[geni])
                    , .result(gTimeGTEcurrent_pulse_tf[geni])
                    , .rdy(gTimeGTEcurrent_pulse_tf_rdy[geni]));

      fgte gTime_exposureGTEt1(.clk(CLK), .sclr(RESET)
        , .operation_nd(updater_d_fifo_ack)
        , .a(gTime_exposure), .b(current_pulse_t1_d[geni])
        , .result(gTime_exposureGTEcurrent_pulse_t1[geni])
        , .rdy(gTime_exposureGTEcurrent_pulse_t1_rdy[geni]));

      fsub time2_time1(.clk(CLK), .sclr(RESET)
                     , .operation_nd(pulse_desc_valid_d[FCOMP_LATENCY-1])
                     , .a(time2_d[geni][FCOMP_LATENCY-1]), .b(time1[geni])
                     , .result(projection_duration[geni])
                     , .rdy(projection_duration_rdy[geni]));

      better_fifo#(.TYPE("Pulse"), .WIDTH(PULSE_DESC_SIZE), .DELAY(DELAY))
      updater_d_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                     , .din({current_pulse_t1[geni], current_pulse_dt[geni]
                           , current_pulse_dye[geni]
                           , current_pulse_in_idx[geni]
                           , current_pulse_zmw_number})
                     , .wren(from_ram_fifo_valid)
                     , .full(updater_d_fifo_full[geni]), .high(), .almost_full()
                     , .rden(updater_d_fifo_ack)
                     , .dout({current_pulse_t1_d[geni], current_pulse_dt_d[geni]
                            , current_pulse_dye_d[geni]
                            , current_pulse_in_idx_d[geni]
                            , current_pulse_zmw_number_d[geni]})
                    , .empty(updater_d_fifo_empty[geni]), .almost_empty());

      better_fifo#(.TYPE("FPandZMW"), .WIDTH(FP_SIZE+N_ZMW_SIZE)
                 , .DELAY(DELAY))
      intensity_d_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                     , .wren(pulse_desc_valid_d[0])//updater_d_fifo_ack delayed
                     , .din({current_pulse_intensity[geni]
                           , current_pulse_zmw_number_dd})
                     , .high(), .full(), .almost_full()
                     , .rden(projection_duration_rdy[geni])
                     , .dout({pulse_intensity[geni], pulse_intensity_zmw[geni]})
                     , .empty(intensity_d_fifo_empty[geni]), .almost_empty());

      fmult duraXintens(.clk(CLK), .sclr(RESET)
                  , .operation_nd(projection_duration_rdy[geni])
                  , .a(projection_duration[geni]), .b(pulse_intensity[geni])
                  , .result(durationXintensity[geni])
                  , .rdy(durationXintensity_rdy[geni]));

      for(genj=0; genj<N_DYE; genj=genj+1)
        assign #DELAY pulse_strength[geni][genj] = (pulse_dye[geni] == genj)
                                                 ? durationXintensity[geni] : 0;
    end//for(MAX_PULSE_PER_ZMW)/////////////////////////////////////

    better_fifo#(.TYPE("DYEandZMW"), .WIDTH(N_DYE*DYE_SIZE+N_ZMW_SIZE+1)
               , .DELAY(DELAY))
    dye_d_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
             , .wren(updater_d_fifo_ack || xof)
             , .din({current_pulse_dye_d[2]
                   , current_pulse_dye_d[1]
                   , current_pulse_dye_d[0]
                   , current_pulse_zmw_number_d[0], xof})
             , .high(), .full(dye_d_fifo_full), .almost_full()
             , .rden(dye_d_fifo_ack)
             , .dout({pulse_dye[2], pulse_dye[1], pulse_dye[0]
                    , pulse_dye_zmw, xof_d})
             , .empty(dye_d_fifo_empty), .almost_empty());

    //Pulse de-multiplexer////////////////////////////////////////////
    for(geni=0; geni<N_DYE; geni=geni+1) begin
      fadd fadd_strength01(.clk(CLK), .sclr(RESET)
          , .operation_nd(durationXintensity_rdy[0])
          , .a(pulse_strength[0][geni]), .b(pulse_strength[1][geni])
          , .result(strength01[geni]), .rdy(strength01_rdy[geni]));
      fadd strength2_identity(.clk(CLK), .sclr(RESET)
          , .operation_nd(durationXintensity_rdy[0])
          , .a(pulse_strength[2][geni]), .b(0)
          , .result(strength2_d[geni]), .rdy());
      fadd fadd_strength012(.clk(CLK), .sclr(RESET)
          , .operation_nd(strength01_rdy[geni])
          , .a(strength01[geni]), .b(strength2_d[geni])
          , .result(strength012[geni]), .rdy(strength012_rdy[geni]));
    end//for(N_DYE)

    better_fifo#(.TYPE("DYEandZMW"), .WIDTH(N_DYE*DYE_SIZE+N_ZMW_SIZE+1)
               , .DELAY(DELAY))
    zmwxof_d_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .wren(dye_d_fifo_ack)
                , .din({pulse_dye[2], pulse_dye[1], pulse_dye[0]
                      , pulse_dye_zmw, xof_d})
                , .high(), .full(zmwxof_d_fifo_full), .almost_full()
                , .rden(zmwxof_d_fifo_ack)
                , .dout({pulse_dye_d[2], pulse_dye_d[1], pulse_dye_d[0]
                       , pulse_dye_zmw_d, xof_dd})
                , .empty(zmwxof_d_fifo_empty), .almost_empty());

    //The Ping-Pong RAM/////////////////////////////////////////////
    for(geni=0; geni<2; geni=geni+1) begin
      better_fifo#(.TYPE("ToRAM"), .WIDTH(RAM_DATA_SIZE), .DELAY(DELAY))
      to_ram_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .din({to_ram_fifo_data, to_ram_fifo_header[geni]})
                , .wren(to_ram_fifo_wren[geni]), .full(to_ram_fifo_full[geni])
                , .almost_full(to_ram_fifo_almost_full[geni])
                , .high(to_ram_fifo_high[geni])
                , .rden(to_ram_fifo_ack[geni]), .dout(to_ram_fifo_dout[geni])
                , .empty(to_ram_fifo_empty[geni])
                , .almost_empty(to_ram_fifo_almost_empty[geni]));

      assign #DELAY to_ram_fifo_ack[geni] = to_ram_fifo_valid[geni] &&
`ifdef STRAIGHTFORWARD_TO_RAM_FIFIO_ACK
          (ram_state[geni] == RAM_IDLE
        || ram_state[geni] == RAM_MSG_WAIT1
        || (ram_state[geni] == RAM_MSG_WAIT2 && //6
            to_ram_fifo_dout[geni][0] == `FALSE)//control message
        || (ram_state[geni] == RAM_WR1 && //5
            (to_ram_fifo_dout[geni][0] == `FALSE ||//control message
             ram_wdf_rdy[geni]))
        || (ram_state[geni] == RAM_WR2)
        || (ram_state[geni] == RAM_READING)
        || (ram_state[geni] == RAM_THROTTLED));
`else
        !((ram_state[geni] == RAM_MSG_WAIT2 && to_ram_fifo_dout[geni][0]) ||
          (ram_state[geni] == RAM_WR_WAIT) ||
          (ram_state[geni] == RAM_WR1 && to_ram_fifo_dout[geni][0] && //is data
           !ram_wdf_rdy[geni]));
`endif

      PulseListBRAM
      list(.clka(CLK), .douta(ram_rd_data[geni])
         , .addra(ram_addr[geni]), .dina(ram_wdf_data)
         , .wea(ram_wdf_wren[geni]));             
    end//for Ping-Pong RAM/////////////////////////////////////////////
  endgenerate

  localparam MSG_HEADER_TYPE_BIT = 0
           , CONTROL_MSG_START_BIT = 6
           , CONTROL_MSG_N_FRAME_BIT = 8, CONTROL_MSG_N_FRAME_SIZE = 24
           , CONTROL_MSG_N_CLOCK_PER_FRAME_BIT = CONTROL_MSG_N_FRAME_BIT
                                               + CONTROL_MSG_N_FRAME_SIZE
           , CONTROL_MSG_N_CLOCK_PER_FRAME_SIZE = 24
           , CONTROL_MSG_STRIDE_BIT = CONTROL_MSG_N_CLOCK_PER_FRAME_BIT
                                    + CONTROL_MSG_N_CLOCK_PER_FRAME_SIZE
           , CONTROL_MSG_STRIDE_SIZE = 8
           , CONTROL_MSG_EXPOSURE_BIT = CONTROL_MSG_STRIDE_BIT
                                      + CONTROL_MSG_STRIDE_SIZE
           , CONTROL_MSG_EXPOSURE_SIZE = FP_SIZE;
  wire is_control_msg, is_start_msg, is_stop_msg, is_pulse_msg;
  //A PC message is either a camera control message (START/STOP; see design doc)
  //or data (pulse description) message
  assign #DELAY is_control_msg = whole_pc_msg_valid
                              && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE;
  assign #DELAY is_start_msg = whole_pc_msg_valid
             && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE//control msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `TRUE;//start msg
  assign #DELAY is_stop_msg = whole_pc_msg_valid
             && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE//control msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE;//stop msg

  localparam PULSE_DESC_SIZE = FP_SIZE + FP_SIZE + 2 + 2 + 22;//90;
  wire[FP_SIZE-1:0] new_pulse_t1, new_pulse_dt;
  wire[1:0]  new_pulse_dye, new_pulse_intensity;
  wire[N_ZMW_SIZE-1:0] new_pulse_zmw_num;
  assign #DELAY is_pulse_msg = whole_pc_msg_valid
                            && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `TRUE;
  wire assembler2updater_fifo_ack, assembler2updater_fifo_full
     , assembler2updater_fifo_empty;

  better_fifo#(.TYPE("Pulse"), .WIDTH(PULSE_DESC_SIZE), .DELAY(DELAY))
  assembler2updater_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .wren(is_pulse_msg && !assembler2updater_fifo_full)
                , .din(whole_pc_msg[CONTROL_MSG_START_BIT+:PULSE_DESC_SIZE])
                , .high(), .full(assembler2updater_fifo_full), .almost_full()
                , .rden(assembler2updater_fifo_ack)
                , .dout({new_pulse_t1, new_pulse_dt, new_pulse_dye
                       , new_pulse_intensity, new_pulse_zmw_num})
                , .empty(assembler2updater_fifo_empty), .almost_empty());

  assign #DELAY pc_msg_ack = pc_msg_valid && !assembler2updater_fifo_full;
  
  assign #DELAY assembler2updater_fifo_ack = pacer_state == PACER_FRAME
    && gTimeGTEcurrent_pulse_tf_rdy[0]//(gTime >= Tf) result ready
    && !assembler2updater_fifo_empty
    && (//There is a new pulse, but not THIS ZMW
        new_pulse_zmw_num != current_pulse_zmw_number
        //New pulse and current ZMW number match, and at least one of the
        //pulse has expired (=> I can take the new update)
        || gTimeGTEcurrent_pulse_tf != {MAX_PULSE_PER_ZMW{`FALSE}});
        
  assign #DELAY updater_d_fifo_ack =
    (pacer_state == PACER_FRAME
     || (pacer_state == PACER_FRAME_THROTTLED
         && n_clock_throttled < PULSE_EXPIRATION_DETERMINATION_LATENCY))
    //Although I test only 1st wires from this bus of width MAX_PULSE_PER_ZMW,
    //the other 2 wires in array are identical in next few lines
    && gTimeGTEcurrent_pulse_tf_rdy[0]
    && !updater_d_fifo_empty[0];
    
  assign #DELAY xof = pacer_state == PACER_STARTING_FRAME
                   || pacer_state == PACER_STOPPING_FRAME;

  assign #DELAY dye_d_fifo_ack = durationXintensity_rdy[0]
                               || (!dye_d_fifo_empty && xof_d);

  assign #DELAY zmwxof_d_fifo_ack = !zmwxof_d_fifo_empty
                                  && (strength012_rdy[0] || xof_dd);

  //sequential logic ////////////////////////////////////////////////////////
  integer i, j;
  always @(posedge CLK) begin
    current_pulse_zmw_number_dd <= #DELAY current_pulse_zmw_number_d[0];
    
    pulse_desc_valid_d[0] <= #DELAY updater_d_fifo_ack;
    for(j=1; j < FCOMP_LATENCY; j=j+1)
      pulse_desc_valid_d[j] <= #DELAY pulse_desc_valid_d[j-1];

    for(i=0; i < MAX_PULSE_PER_ZMW; i=i+1) begin
      current_pulse_intensity[i] <= #DELAY
        pulse_intensity_pool[current_pulse_in_idx_d[i]];

      time1[i] <= #DELAY //MAX(current_pulse_t1_dd, gTime-exposure)
        gTime_exposureGTEcurrent_pulse_t1[i]
        ? gTime_exposure : current_pulse_t1_dd[i][FCOMP_LATENCY-1];

      current_pulse_tf_d[i][0] <= #DELAY current_pulse_tf[i];      
      for(j=1; j < FCOMP_LATENCY; j=j+1)
        current_pulse_tf_d[i][j] <= #DELAY current_pulse_tf_d[i][j-1];

      time2_d[i][0] <= #DELAY //MIN(current_pulse_tf_d, gTime)
        gTimeGTEcurrent_pulse_tf[i] ? current_pulse_tf_d[i][FCOMP_LATENCY-1]
                                    : gTime;
      for(j=1; j<FCOMP_LATENCY; j=j+1) time2_d[i][j] <= #DELAY time2_d[i][j-1];

      current_pulse_t1_dd[i][0] <= #DELAY current_pulse_t1_d[i];
      for(j=1; j<FCOMP_LATENCY; j=j+1)
        current_pulse_t1_dd[i][j] <= #DELAY current_pulse_t1_dd[i][j-1];
        
      //for(j=1; j<N_DYE; j=j+1)
      //  pulse_strength[i][j] <= #DELAY (pulse_dye[i] == j)
      //                        ? durationXintensity[i] : 0;
    end//for(MAX_PULSE_PER_ZMW)

    downstream_wren <= #DELAY zmwxof_d_fifo_ack;
    downstream_din <= #DELAY {strength012[0]
                      , 2'b00, pulse_dye_zmw_d, 3'b000, xof_dd, pacer_state};

    from_ram_fifo_wren <= #DELAY ram_rd_data_valid[from_ram_src];

    if(RESET) begin
      //For now, hard code the intensity pool values
      pulse_intensity_pool[0] <= #DELAY 'h3e800000; //0.25f
      pulse_intensity_pool[1] <= #DELAY 'h3f000000; //0.5f
      pulse_intensity_pool[2] <= #DELAY 'h3f400000; //0.75f
      pulse_intensity_pool[3] <= #DELAY 'h3f800000; //1.0f
      
      gTime_cal_en <= #DELAY `FALSE;
      msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT1;
      pacer_state <= #DELAY PACER_STOPPED;
      for(i=0; i<2; i=i+1) begin
        ram_en[i] <= #DELAY `FALSE;
        ram_read[i] <= #DELAY `FALSE;    
        to_ram_fifo_header[i] <= #DELAY 0;
        to_ram_fifo_wren[i] <= #DELAY `FALSE;
        ram_wdf_wren[i] <= #DELAY `FALSE;
        ram_state[i] <= #DELAY RAM_IDLE;
      end
      from_ram_src <= #DELAY `FALSE;
    end else begin

      ram_en_and_read[0] <= #DELAY ram_en & ram_read;//bitwise
      for(i=1; i<BRAM_READ_LATENCY-1; i=i+1)
        ram_en_and_read[i] <= #DELAY ram_en_and_read[i-1];
      ram_rd_data_valid <= #DELAY ram_en_and_read[BRAM_READ_LATENCY-2];
      from_ram_fifo_din <= #DELAY ram_rd_data[from_ram_src];
  
      //PC message assembler code ///////////////////////////////////////
      whole_pc_msg_valid <= #DELAY `FALSE;
      if(!assembler2updater_fifo_full) begin
        case(msg_assembler_state)
          MSG_ASSEMBLER_WAIT1:
            if(pc_msg_valid) begin
              msg_assembler_cache[0+:XB_SIZE] <= #DELAY pc_msg;
              msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT2;
            end
          MSG_ASSEMBLER_WAIT2:
            if(pc_msg_valid) begin
              msg_assembler_cache[XB_SIZE+:XB_SIZE] <= #DELAY pc_msg;
              msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT3;
            end
          MSG_ASSEMBLER_WAIT3:
            if(pc_msg_valid) begin
              msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT1;
              whole_pc_msg <= #DELAY {pc_msg, msg_assembler_cache};
              whole_pc_msg_valid <= #DELAY `TRUE;
            end
          default: begin
          end
        endcase//msg_assembler_state
      end//if(!assembler2updater_fifo_full)
      
      //Pacer code ////////////////////////////////////////////////////
      gTime_cal_en <= #DELAY `FALSE;
      if(nframeXexp_rdy) gTime <= #DELAY nframeXexp;
      if(nframe_1Xexp_rdy) gTime_exposure <= #DELAY nframe_1Xexp;
      
      for(i=0; i<2; i=i+1) to_ram_fifo_wren[i] <= #DELAY `FALSE;

      if(downstream_overflow) pacer_state <= #DELAY PACER_ERROR;
      else begin//!downstream_overflow
        case(pacer_state)
          PACER_STOPPED:
            if(is_start_msg) begin
              max_frame <= #DELAY whole_pc_msg[CONTROL_MSG_N_FRAME_BIT
                                             +:CONTROL_MSG_N_FRAME_SIZE];
              clock_per_frame <= #DELAY whole_pc_msg[
                  CONTROL_MSG_N_CLOCK_PER_FRAME_BIT
                +:CONTROL_MSG_N_CLOCK_PER_FRAME_SIZE];
              max_stride <= #DELAY whole_pc_msg[CONTROL_MSG_STRIDE_BIT
                                              +:CONTROL_MSG_STRIDE_SIZE];
              exposure <= #DELAY whole_pc_msg[(3*XB_SIZE-1)-:FP_SIZE];

              // ^START to 1st RAM controller
              to_ram_fifo_data <= #DELAY {ZMW_DATA_SIZE{`FALSE}};            
              to_ram_fifo_header[0][2:0] <= #DELAY 'b110;//START(WR)
              to_ram_fifo_wren[0] <= #DELAY `TRUE;

              wr_zmw <= #DELAY 0;
              from_ram_src <= #DELAY `TRUE;
              pacer_state <= #DELAY PACER_STARTING;
            end

          PACER_STOPPING:
            if(to_ram_fifo_full == 'b00) begin// ^STOP to both RAM controllers
              for(i=0; i<2; i=i+1) begin
                to_ram_fifo_header[i] <= #DELAY 'h00;
                to_ram_fifo_wren[i] <= #DELAY `TRUE;
              end
              pacer_state <= #DELAY PACER_STOPPED;
            end
          
          PACER_STARTING: begin
            n_frame <= #DELAY 0;
            n_stride <= #DELAY 0;
            if(!to_ram_fifo_full[0]) begin
              to_ram_fifo_header[0] <= #DELAY 'h01;//data message from now
              //writing 0 in this cycle, so write 1 next
              wr_zmw <= #DELAY wr_zmw + `TRUE;
              to_ram_fifo_wren[0] <= #DELAY `TRUE;
              gTime_cal_en <= #DELAY `TRUE;
              pacer_state <= #DELAY PACER_INIT;
            end
          end
          
          PACER_INIT:
            if(is_control_msg
               && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE) begin//STOP
              //I can't ^STOP message here because of the possibility of FIFO full
              pacer_state <= #DELAY PACER_STOPPING;//just move to STOPPING
            end else if(to_ram_fifo_full[0]) begin
              to_ram_fifo_wren[0] <= #DELAY `FALSE;
              pacer_state <= #DELAY PACER_INIT_THROTTLED;
            end else begin
              if(wr_zmw == N_ZMW % (2**log2(N_ZMW))
                 && !to_ram_fifo_full[0]) begin
                to_ram_fifo_header[0] <= #DELAY 'h00;// ^STOP to 1st RAM
                n_clock <= #DELAY 0;
                n_clock_throttled <= #DELAY 0;
                pacer_state <= #DELAY PACER_STARTING_FRAME;
              end else begin
                to_ram_fifo_data[0+:log2(N_ZMW)] <= #DELAY wr_zmw;
                wr_zmw <= #DELAY wr_zmw + `TRUE;            
              end
              to_ram_fifo_wren[0] <= #DELAY `TRUE;
            end
          
          PACER_INIT_THROTTLED:
            if(is_control_msg
               && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE) begin//STOP
              pacer_state <= #DELAY PACER_STOPPING;
            end else if(!to_ram_fifo_full[0]) begin
              to_ram_fifo_wren[0] <= #DELAY `TRUE;
              pacer_state <= #DELAY PACER_INIT;
            end
            
          PACER_STARTING_FRAME: begin
            n_clock <= #DELAY n_clock + `TRUE;
            //Wait for both FIFO to free up
            if(!to_ram_fifo_full) begin // ^START to both DRAM managers
              n_frame <= #DELAY n_frame + `TRUE;
              
              //Tell src RAM to start reading, and ~src RAM to start writing.
              //Note that the src appears flipped because flipping happens at the
              //next clock.
              from_ram_src <= ~from_ram_src; // flip the source
              to_ram_fifo_header[~from_ram_src] <= #DELAY 'b00000010;//^START(RD)
              to_ram_fifo_header[from_ram_src] <= #DELAY 'b00000110;//^START(WR)
              to_ram_fifo_wren <= #DELAY 'b11;
              pacer_state <= #DELAY PACER_FRAME;
            end
          end
          
          PACER_FRAME: begin
            n_clock <= #DELAY n_clock + `TRUE;
            //Yes there are 2 others, but they are identical, so it's safe
            //to use just the first for all
            if(gTimeGTEcurrent_pulse_tf_rdy[0]//(gTime >= Tf) calculation ready
                                              // => can update pulse
               && !updater_d_fifo_empty[0]) // current pulse definition ready
            begin//Can update pulse, and current pulse definition is ready
              //Note that new pulse definition is NOT required
              
              //First, check the delayed answer
              if(current_pulse_zmw_number_d[0][0+:log2(N_ZMW)] != rd_zmw) begin
                // ^STOP to both RAM controllers
                for(i=0; i<2; i=i+1) begin
                  to_ram_fifo_header[i] <= #DELAY 'h00;
                  to_ram_fifo_wren[i] <= #DELAY `TRUE;
                end
                pacer_state <= #DELAY PACER_ERROR;
              end else begin
                if(assembler2updater_fifo_empty//no new pulse description
                   //There is new pulse, but it's not THIS zmw
                   || new_pulse_zmw_num != current_pulse_zmw_number
                   //none of the pulse has expired
                   || gTimeGTEcurrent_pulse_tf == {MAX_PULSE_PER_ZMW{`FALSE}}
                 ) begin// => can't update
                  //If there is no new pulse for this ZMW,
                  //just copy all 3 to the ALT RAM
                  to_ram_fifo_data <= #DELAY {
                      current_pulse_t1_d[0], current_pulse_dt_d[0]
                    , current_pulse_t1_d[1], current_pulse_dt_d[1]
                    , current_pulse_t1_d[2], current_pulse_dt_d[2]
                    , 2'b00, current_pulse_dye_d[0]
                    , 2'b00, current_pulse_in_idx_d[0]
                    , 2'b00, current_pulse_dye_d[1]
                    , 2'b00, current_pulse_in_idx_d[1]
                    , 2'b00, current_pulse_dye_d[2]
                    , 2'b00, current_pulse_in_idx_d[2]
                    , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                end else begin // a new pulse has to be saved to the ALT RAM
                //Which slot to grab?
                  if(gTimeGTEcurrent_pulse_tf[0]) begin//pulse[0] is expired
                    to_ram_fifo_data <= #DELAY {
                        new_pulse_t1, new_pulse_dt
                      , current_pulse_t1_d[1], current_pulse_dt_d[1]
                      , current_pulse_t1_d[2], current_pulse_dt_d[2]
                      , 2'b00, new_pulse_dye, 2'b00, new_pulse_intensity
                      , 2'b00, current_pulse_dye_d[1]
                      , 2'b00, current_pulse_in_idx_d[1]
                      , 2'b00, current_pulse_dye_d[2]
                      , 2'b00, current_pulse_in_idx_d[2]
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else if(gTimeGTEcurrent_pulse_tf[1]) begin
                    //pulse[1] is expired => take slot 1
                    to_ram_fifo_data <= #DELAY {
                        current_pulse_t1_d[0], current_pulse_dt_d[0]
                      , new_pulse_t1, new_pulse_dt
                      , current_pulse_t1_d[2], current_pulse_dt_d[2]
                      , 2'b00, current_pulse_dye_d[0]
                      , 2'b00, current_pulse_in_idx_d[0]
                      , 2'b00, new_pulse_dye, 2'b00, new_pulse_intensity
                      , 2'b00, current_pulse_dye_d[2]
                      , 2'b00, current_pulse_in_idx_d[2]
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else if(gTimeGTEcurrent_pulse_tf[2]) begin
                    //pulse[2] is expired => take slot 2
                    to_ram_fifo_data <= #DELAY {
                        current_pulse_t1_d[0], current_pulse_dt_d[0]
                      , current_pulse_t1_d[1], current_pulse_dt_d[1]
                      , new_pulse_t1, new_pulse_dt
                      , 2'b00, current_pulse_dye_d[0]
                      , 2'b00, current_pulse_in_idx_d[0]
                      , 2'b00, current_pulse_dye_d[1]
                      , 2'b00, current_pulse_in_idx_d[1]
                      , 2'b00, new_pulse_dye, 2'b00, new_pulse_intensity
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else begin
                    //full => can't update, don't ACK
                  end
                end //else: a new pulse definition has to be saved to ALT

                //Write the updated (could be the same as current) pulse
                //description to ALT; note that we always write in this state
                //unless there is an error
                to_ram_fifo_header[~from_ram_src] <= #DELAY 'h01; // is data
                to_ram_fifo_wren[~from_ram_src] <= #DELAY `TRUE;
                rd_zmw <= #DELAY rd_zmw + `TRUE;
                
                if(rd_zmw == N_ZMW-1) begin // done checking
                  // ^STOP to RAM[src]
                  to_ram_fifo_header[from_ram_src] <= #DELAY 'b0000_0000;
                  to_ram_fifo_wren[from_ram_src] <= #DELAY `TRUE;
                  pacer_state <= #DELAY PACER_STOPPING_FRAME;
                end else if(to_ram_fifo_high[~from_ram_src]
                            || downstream_high) begin
                  pacer_state <= #DELAY PACER_FRAME_THROTTLED;
                end//!if(rd_zmw == N_ZMW-1)

              end //else: not an error condition
            end //Can update pulse, and current pulse definition is ready
          end //case PACER_FRAME
          
          PACER_FRAME_THROTTLED: begin//delayed Tf calculation will keep coming
            //for PULSE_EXPIRATION_DETERMINATION_LATENCY after entry
            n_clock <= #DELAY n_clock + `TRUE;
            n_clock_throttled <= #DELAY n_clock_throttled + `TRUE;
            
            if(!(to_ram_fifo_high[~from_ram_src] || downstream_high))
            begin //The default logic,
              n_clock_throttled <= #DELAY 0;
              pacer_state <= #DELAY PACER_FRAME;
            end//which may be overridden by valid current pulse definition below
            
            if(n_clock_throttled < PULSE_EXPIRATION_DETERMINATION_LATENCY
               && gTimeGTEcurrent_pulse_tf_rdy[0]
               && !updater_d_fifo_empty[0]) begin//consume comparison result
              //First, check the delayed answer
              if(current_pulse_zmw_number_d[0][0+:log2(N_ZMW)] != rd_zmw) begin
                // ^STOP to both RAM controllers
                for(i=0; i<2; i=i+1) begin
                  to_ram_fifo_header[i] <= #DELAY 'h00;
                  to_ram_fifo_wren[i] <= #DELAY `TRUE;
                end
                pacer_state <= #DELAY PACER_ERROR;
              end else begin
                if(assembler2updater_fifo_empty//no new pulse description
                   //There is new pulse, but it's not THIS one
                   || new_pulse_zmw_num != current_pulse_zmw_number
                   //none of the pulse has expired => can't update
                   || gTimeGTEcurrent_pulse_tf == {MAX_PULSE_PER_ZMW{`FALSE}})
                begin
                  //If there is no new pulse for this ZMW,
                  //just copy all 3 to the ALT RAM
                  to_ram_fifo_data <= #DELAY {
                      current_pulse_t1_d[0], current_pulse_dt_d[0]
                    , current_pulse_t1_d[1], current_pulse_dt_d[1]
                    , current_pulse_t1_d[2], current_pulse_dt_d[2]
                    , 2'b00, current_pulse_dye_d[0]
                    , 2'b00, current_pulse_in_idx_d[0]
                    , 2'b00, current_pulse_dye_d[1]
                    , 2'b00, current_pulse_in_idx_d[1]
                    , 2'b00, current_pulse_dye_d[2]
                    , 2'b00, current_pulse_in_idx_d[2]
                    , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                end else begin // a new pulse has to be saved to the ALT RAM
                //Which slot to grab?
                  if(gTimeGTEcurrent_pulse_tf[0]) begin//pulse[0] is expired
                    to_ram_fifo_data <= #DELAY {
                        new_pulse_t1, new_pulse_dt
                      , current_pulse_t1_d[1], current_pulse_dt_d[1]
                      , current_pulse_t1_d[2], current_pulse_dt_d[2]
                      , 2'b00, new_pulse_dye, 2'b00, new_pulse_intensity
                      , 2'b00, current_pulse_dye_d[1]
                      , 2'b00, current_pulse_in_idx_d[1]
                      , 2'b00, current_pulse_dye_d[2]
                      , 2'b00, current_pulse_in_idx_d[2]
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else if(gTimeGTEcurrent_pulse_tf[1]) begin
                    //pulse[1] is expired => take slot 1
                    to_ram_fifo_data <= #DELAY {
                        current_pulse_t1_d[0], current_pulse_dt_d[0]
                      , new_pulse_t1, new_pulse_dt
                      , current_pulse_t1_d[2], current_pulse_dt_d[2]
                      , 2'b00, current_pulse_dye_d[0]
                      , 2'b00, current_pulse_in_idx_d[0]
                      , 2'b00, new_pulse_dye, 2'b00, new_pulse_intensity
                      , 2'b00, current_pulse_dye_d[2]
                      , 2'b00, current_pulse_in_idx_d[2]
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else if(gTimeGTEcurrent_pulse_tf[2]) begin
                    //pulse[2] is expired => take slot 2
                    to_ram_fifo_data <= #DELAY {
                        current_pulse_t1_d[0], current_pulse_dt_d[0]
                      , current_pulse_t1_d[1], current_pulse_dt_d[1]
                      , new_pulse_t1, new_pulse_dt
                      , 2'b00, current_pulse_dye_d[0]
                      , 2'b00, current_pulse_in_idx_d[0]
                      , 2'b00, current_pulse_dye_d[1]
                      , 2'b00, current_pulse_in_idx_d[1]
                      , 2'b00, new_pulse_dye, 2'b00, new_pulse_intensity
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else begin
                    //full => can't update, don't ACK
                  end
                end //else: a new pulse definition has to be saved to ALT

                //Write the updated (could be the same as current) pulse
                //description to ALT; note that we always write in this state
                //unless there is an error
                to_ram_fifo_header[~from_ram_src] <= #DELAY 'h01; // is data
                to_ram_fifo_wren[~from_ram_src] <= #DELAY `TRUE;
                rd_zmw <= #DELAY rd_zmw + `TRUE;

                if(rd_zmw == N_ZMW-1) begin // done checking
                  // ^STOP to RAM[src]
                  to_ram_fifo_header[from_ram_src] <= #DELAY 'b0000_0000;
                  to_ram_fifo_wren[from_ram_src] <= #DELAY `TRUE;
                  pacer_state <= #DELAY PACER_STOPPING_FRAME;
                end//!if(rd_zmw == N_ZMW-1)
              end //else: not an error condition
            end//valid current pulse definition
          end//PACER_FRAME_THROTTLED

          PACER_STOPPING_FRAME: begin
            n_clock <= #DELAY n_clock + `TRUE;
            //^EOF
            if(n_frame == max_frame) pacer_state <= #DELAY PACER_STOPPING;
            else if(!to_ram_fifo_full[~from_ram_src]) begin
              //^STOP to RAM[~src]
              to_ram_fifo_header[~from_ram_src] <= #DELAY 'b0000_0000;
              to_ram_fifo_wren[~from_ram_src] <= #DELAY `TRUE;
              gTime_cal_en <= #DELAY `TRUE;
              pacer_state <= #DELAY PACER_INTERFRAME;
            end
          end
          
          PACER_INTERFRAME: begin
            n_clock <= #DELAY n_clock + `TRUE;
            if(n_clock == clock_per_frame) begin
              n_clock <= #DELAY 0;
              pacer_state <= #DELAY PACER_STARTING_FRAME;
            end
          end
          
          default: begin // ERROR
            to_ram_fifo_wren <= #DELAY {`FALSE, `FALSE};
          end
        endcase//pacer_state
      end //!downstream_overflow
      
      // DRAM manager code /////////////////////////////////////////////
      for(i=0; i<2; i=i+1) begin // Dual RAM => dual statemachine
        //to_ram_fifo_ack[i] <= #DELAY `FALSE;//don't ACK by default
        case(ram_state[i])
          RAM_IDLE: begin
            ram_addr[i] <= #DELAY 0;
            if(to_ram_fifo_valid[i]) begin              
              if(to_ram_fifo_dout[i][0] == `FALSE //control message
                 && to_ram_fifo_dout[i][1] == `TRUE) begin //SOF
                if(to_ram_fifo_dout[i][2] == `TRUE) begin
                  ram_en[i] <= #DELAY `FALSE;
                  ram_state[i] <= #DELAY RAM_MSG_WAIT1;
                end else begin
                  ram_read[i] <= #DELAY `TRUE;
                  ram_en[i] <= #DELAY `TRUE;
                  rd_zmw <= #DELAY 0;
                  ram_state[i] <= #DELAY RAM_READING;
                end
              end
              
              //to_ram_fifo_ack[i] <= #DELAY `TRUE;
            end
          end

          RAM_MSG_WAIT1:
            if(to_ram_fifo_valid[i]) begin
              if(to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
                if(to_ram_fifo_dout[i][1] == `FALSE) begin //EOF
                  ram_state[i] <= #DELAY RAM_IDLE;
                end//If SOF, just ignore, since RAM is in SAVING state already
              end else begin//There is at least 1 data
                to_ram_cache[i] <= #DELAY to_ram_fifo_dout[i];
                ram_state[i] <= #DELAY RAM_MSG_WAIT2;
              end
              
              //to_ram_fifo_ack[i] <= #DELAY `TRUE;
            end
            
          RAM_MSG_WAIT2:
            if(to_ram_fifo_valid[i]) begin
              if(to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
                if(to_ram_fifo_dout[i][1] == `FALSE) begin //EOF
                  ram_state[i] <= #DELAY RAM_IDLE;
                end//If SOF, just ignore, since RAM is in SAVING state already
                //to_ram_fifo_ack[i] <= #DELAY `TRUE; //ACK the control msg
              end else begin//There 1 more data at the head of FIFO; don't pop
                //begin the burst write
                ram_read[i] <= #DELAY `FALSE;
                ram_en[i] <= #DELAY `TRUE;
                ram_state[i] <= #DELAY RAM_WR_WAIT;
              end
            end

          RAM_WR_WAIT: //wait for the HW to grant write
            if(ram_rdy[i] && ram_wdf_rdy[i]) begin
              ram_wdf_data <= #DELAY to_ram_cache[i];//first write the stored
              // Write at the current ram_addr[i]
              ram_wdf_wren[i] <= #DELAY `TRUE;
              ram_state[i] <= #DELAY RAM_WR1;
            end
          
          RAM_WR1://HW writing the 1st of the pair in this state
            //We transitioned to this state because there IS message in FIFO
            //But is it a control message?
            if(to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
              if(to_ram_fifo_dout[i][1] == `FALSE) begin //EOF
                ram_en[i] <= #DELAY `FALSE;//turn things off by default
                //abandon the information in to_ram_cache
                ram_state[i] <= #DELAY RAM_IDLE;
              end//If SOF, just ignore, since RAM is in SAVING state already
              //to_ram_fifo_ack[i] <= #DELAY `TRUE; //ACK the control msg
            end else if(ram_wdf_rdy[i]) begin//always TRUE for BRAM
              //we are here because there IS data in FIFO
              ram_wdf_data <= #DELAY to_ram_fifo_dout[i];//get it now
              ram_wdf_wren[i] <= #DELAY `TRUE;//write the 2nd data
              ram_addr[i] <= #DELAY ram_addr[i] + RAM_ADDR_INCR;//move pointer
              //to_ram_fifo_ack[i] <= #DELAY `TRUE;//and acknowledge data
              ram_state[i] <= #DELAY RAM_WR2;
            end
            
          RAM_WR2: begin//HW writing the 2nd of the pair in this state
            ram_en[i] <= #DELAY `FALSE;//turn things off by default
            ram_wdf_wren[i] <= #DELAY `FALSE;

            //What to do next?
            if(to_ram_fifo_valid[i]) begin //There IS a message from pacer
              if(to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
                if(to_ram_fifo_dout[i][1] == `FALSE) begin//EOF/STOP
                  ram_state[i] <= #DELAY RAM_IDLE;
                end else begin// SOF => ignore
                  ram_state[i] <= #DELAY RAM_MSG_WAIT1;
                end
              end else begin // there is DATA, but how many?
                //Since I just wrote (the 2nd of the burst), I have to increment
                //address for the future write
                ram_addr[i] <= #DELAY ram_addr[i] + RAM_ADDR_INCR;
                
                to_ram_cache[i] <= #DELAY to_ram_fifo_dout[i];//save the 1st
                if(to_ram_fifo_almost_empty[i]) begin
                  //just 1 message => don't write; wait for 2nd
                  ram_state[i] <= #DELAY RAM_MSG_WAIT2;
                end else begin//there are 2 messages => can burst
                  ram_en[i] <= #DELAY `TRUE;
                  if(ram_wdf_rdy[i]) begin //HW already ready to write =>
                    //no clock cycle to save to cache => just grab what's in FIFO
                    ram_wdf_data <= #DELAY to_ram_fifo_dout[i];
                    ram_wdf_wren[i] <= #DELAY `TRUE;
                    //ram_addr[i] <= #DELAY ram_addr[i] + RAM_ADDR_INCR;
                    ram_state[i] <= #DELAY RAM_WR1;
                  end else begin//HW not ready
                    to_ram_cache[i] <= #DELAY to_ram_fifo_dout[i];//save away
                    ram_state[i] <= #DELAY RAM_WR_WAIT;
                  end
                end
              end
              //to_ram_fifo_ack[i] <= #DELAY `TRUE;//acknowledge it
            end else begin// no message at all => wait for msg
              ram_state[i] <= #DELAY RAM_MSG_WAIT1;
            end
          end

          RAM_READING:
            if(to_ram_fifo_valid[i]//There IS a message from pacer
              && to_ram_fifo_dout[i][1:0] == 'b00) begin//STOP message
              ram_en[i] <= #DELAY `FALSE;
              ram_state[i] <= #DELAY RAM_IDLE;
              //Ignore all other messages
              //Don't forget to ACK the message in combinational logic
            end else begin
              if(from_ram_fifo_full) begin
                ram_en[i] <= #DELAY `FALSE;
                ram_state[i] <= #DELAY RAM_ERROR;
              end else if(from_ram_fifo_high) begin
                ram_en[i] <= #DELAY `FALSE;
                ram_state[i] <= #DELAY RAM_THROTTLED;
              end else begin
                ram_addr[i] <= #DELAY ram_addr[i] + RAM_ADDR_INCR;
                if(ram_addr[i] == N_ZMW-1) begin
                  ram_en[i] <= #DELAY `FALSE;
                  ram_state[i] <= #DELAY RAM_IDLE;
                end
              end
            end
          
          RAM_THROTTLED:
            if(to_ram_fifo_valid[i]//There IS a message from pacer
              && to_ram_fifo_dout[i][1:0] == 'b00) begin//STOP message
              ram_en[i] <= #DELAY `FALSE;
              ram_state[i] <= #DELAY RAM_IDLE;
              //Ignore all other messages
              //Don't forget to ACK the message in combinational logic
            end else begin
              if(from_ram_fifo_full) begin
                ram_en[i] <= #DELAY `FALSE;
                ram_state[i] <= #DELAY RAM_ERROR;
              end else if(!from_ram_fifo_high) begin
                ram_en[i] <= #DELAY `TRUE;
                ram_state[i] <= #DELAY RAM_READING;
              end
            end
          
          default: begin
          end
          
        endcase//ram_state[i]
      end//for(i)
    end//!RESET
  end//always @(posedge CLK)
endmodule
