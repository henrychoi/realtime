module application#(parameter SIMULATION=1, DELAY=1, XB_SIZE=32, RAM_DATA_SIZE=1)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output pc_msg_ack
, output reg downstream_wren, output reg [2*XB_SIZE-1:0] downstream_din
, input downstream_high, downstream_overflow
, output app_running, app_error);
`include "function.v"
  genvar geni, genj, genk;
  integer i, j, k;

  localparam N_ZMW_SIZE = log2(4 * 1024 * 1024);
  localparam PULSE_RAM_HEADER_SIZE = 8
           , PULSES_DESC_SIZE = RAM_DATA_SIZE - PULSE_RAM_HEADER_SIZE
           , FP_SIZE = 32, DYE_SIZE = 2, N_DYE = 2**DYE_SIZE
           , INTENSITY_INDEX_SIZE = 4
           , MAX_STRIDE = 2**8 - 1, MAX_CLOCK_PER_FRAME = 2**24 - 1
           , MAX_FRAME = 2**24 - 1;
  reg [log2(MAX_STRIDE)-1:0] max_stride, n_stride;
  reg [log2(MAX_CLOCK_PER_FRAME)-1:0] clock_per_frame, n_clock
                                    , n_clock_throttled;
  reg [log2(MAX_FRAME)-1:0] max_frame, n_frame;
  wire[log2(MAX_FRAME):0] n_frame_1;//n_frame - 1, so could be -1, so extra bit
  assign n_frame_1 = n_frame - 1;
  reg [FP_SIZE-1:0] exposure;
  
  reg [2*RAM_DATA_SIZE-1:0] whole_pc_msg;

  localparam N_ZMW = 128;
  localparam RAM_ADDR_INCR = `TRUE //my way of saying 1 while avoiding warning
           , OUTPUT_REGISTERED_BRAM_READ_LATENCY = 3;//minimum: 1 + 2 to register dout

  // Pulse stage ////////////////////////////////////////////////////////
  localparam PACER_ERROR = 0, PACER_STOPPED = 1, PACER_STOPPING = 2
           , PACER_STARTING = 3, PACER_INIT = 4, PACER_INIT_THROTTLED = 5
           , PACER_STARTING_FRAME = 6, PACER_FRAME = 7
           , PACER_FRAME_THROTTLED = 8, PACER_STOPPING_FRAME = 9
           , PACER_INTERFRAME = 10, PACER_N_STATE = 11;
  reg [log2(PACER_N_STATE)-1:0] pacer_state;
  assign #DELAY app_running = pacer_state >= PACER_STARTING_FRAME;
  assign #DELAY app_error = !pacer_state; 
  assign #DELAY GPIO_LED = {pacer_state};
  
  localparam PULSE_RAM_ERROR = 0, PULSE_RAM_IDLE = 1
           , PULSE_RAM_MSG_WAIT1 = 2, PULSE_RAM_MSG_WAIT2 = 3
           , PULSE_RAM_WR_WAIT = 4, PULSE_RAM_WR1 = 5
           , PULSE_RAM_WR2 = 6, PULSE_RAM_READING = 7
           , PULSE_RAM_THROTTLED = 8, PULSE_RAM_N_STATE = 9;
  reg [log2(PULSE_RAM_N_STATE)-1:0] pulse_ram_state[1:0];
  
  //simulate DRAM interface until we build our own board
  wire[1:0] pulse_ram_rdy, pulse_ram_wdf_rdy;
  reg [1:0] pulse_ram_en, pulse_ram_read
          , pulse_ram_wdf_wren, pulse_ram_wdf_end
          , pulse_ram_en_and_read[OUTPUT_REGISTERED_BRAM_READ_LATENCY-2:0]
          , pulse_ram_rd_data_valid;
  assign pulse_ram_rdy = {`TRUE, `TRUE};
  assign pulse_ram_wdf_rdy = {`TRUE, `TRUE};
  
  localparam FADD_LATENCY = 11, FCOMP_LATENCY = 2
    , PULSE_EXPIRATION_DETERMINATION_LATENCY = FADD_LATENCY + FCOMP_LATENCY;

  reg [log2(N_ZMW)-1:0] pulse_ram_addr[1:0]
                      , pulse_wr_zmw, pulse_rd_zmw;
  reg [6:0] pulse_rom_addr;
  wire[RAM_DATA_SIZE-1:0] pulse_rom_rd_data
                        , pulse_ram_rd_data[1:0], pulse_to_ram_fifo_dout[1:0];
  reg [RAM_DATA_SIZE-1:0] pulse_to_ram_cache[1:0], pulse_ram_wdf_data;
  reg [PULSE_RAM_HEADER_SIZE-1:0] pulse_to_ram_fifo_header[1:0];
  reg [PULSES_DESC_SIZE-1:0]   pulse_to_ram_fifo_data;
  reg[1:0] pulse_to_ram_fifo_wren;
  wire[1:0] pulse_to_ram_fifo_ack //Need Karnaugh logic for ACK, arrrg!
          , pulse_to_ram_fifo_full, pulse_to_ram_fifo_almost_full
          , pulse_to_ram_fifo_high
          , pulse_to_ram_fifo_empty, pulse_to_ram_fifo_almost_empty
          , pulse_to_ram_fifo_valid;
  assign #DELAY pulse_to_ram_fifo_valid
    = {!pulse_to_ram_fifo_empty[1], !pulse_to_ram_fifo_empty[0]};

  wire pulse_from_ram_fifo_ack, pulse_from_ram_fifo_empty
     , pulse_from_ram_fifo_valid
     , pulse_from_ram_fifo_high, pulse_from_ram_fifo_full
     , pulse_from_ram_fifo_almost_full;
  wire[PULSE_RAM_HEADER_SIZE-1:0] pulse_from_ram_fifo_header;
  // register the inputs for timing margin
  reg  pulse_from_ram_src, pulse_from_ram_fifo_wren;
  reg [RAM_DATA_SIZE-1:0] pulse_from_ram_fifo_din;

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
  wire[(4-DYE_SIZE)-1:0] current_pulse_zz[MAX_PULSE_PER_ZMW-1:0];
  wire[INTENSITY_INDEX_SIZE-1:0] current_pulse_in_idx[MAX_PULSE_PER_ZMW-1:0]
                               , current_pulse_in_idx_d[MAX_PULSE_PER_ZMW-1:0];
  wire[9:0] current_pulse_10z;
  wire xof;//either SOF, EOF
  wire[N_ZMW_SIZE-1:0] current_pulse_zmw_number
                     , current_pulse_zmw_number_d[MAX_PULSE_PER_ZMW-1:0]
                     , pulse_intensity_zmw[MAX_PULSE_PER_ZMW-1:0]
                     , pulse_dye_zmw, pulse_dye_zmw_d
                     , strength2_zmw[N_DYE-1:0];
  reg [N_ZMW_SIZE-1:0] current_pulse_zmw_number_dd, pulse_dye_zmw_r;
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
                  , strength012[N_DYE-1:0]
                  , current_pulse_intensity[MAX_PULSE_PER_ZMW-1:0];
  wire[N_DYE-1:0] strength01_rdy, strength012_rdy;
  reg pprojector_msg_valid;

  better_fifo#(.TYPE("FromRAM"), .WIDTH(RAM_DATA_SIZE), .DELAY(DELAY))
  pulse_from_ram_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
    , .wren(pulse_from_ram_fifo_wren), .din(pulse_from_ram_fifo_din)
    , .high(pulse_from_ram_fifo_high), .full(pulse_from_ram_fifo_full)
    , .almost_full(pulse_from_ram_fifo_almost_full)
    , .rden(pulse_from_ram_fifo_ack)
    , .dout({current_pulse_t1[0], current_pulse_dt[0]
           , current_pulse_t1[1], current_pulse_dt[1]
           , current_pulse_t1[2], current_pulse_dt[2]
           , current_pulse_zz[0], current_pulse_dye[0], current_pulse_in_idx[0]
           , current_pulse_zz[1], current_pulse_dye[1], current_pulse_in_idx[1]
           , current_pulse_zz[2], current_pulse_dye[2], current_pulse_in_idx[2]
           , current_pulse_10z, current_pulse_zmw_number
           , pulse_from_ram_fifo_header})
    , .empty(pulse_from_ram_fifo_empty), .almost_empty());
  assign pulse_from_ram_fifo_valid = !pulse_from_ram_fifo_empty;
  assign pulse_from_ram_fifo_ack = pulse_from_ram_fifo_valid //is there anything to ACK?
                          && !pulse_to_ram_fifo_full
                          && !updater_d_fifo_full[0];//chain to updater_d FIFO
  
  generate
    for(geni=0; geni < MAX_PULSE_PER_ZMW; geni=geni+1) begin
      PulseIntensityROM
      pulse_intensity_LUT(.clka(CLK), .addra(current_pulse_in_idx_d[geni])
                        , .douta(current_pulse_intensity[geni]));

      fadd t1Pdt(.clk(CLK), .sclr(RESET), .operation_nd(pulse_from_ram_fifo_valid)
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
                 , current_pulse_in_idx[geni]
                 , current_pulse_dye[geni], current_pulse_zmw_number})
           , .wren(pulse_from_ram_fifo_valid)
           , .full(updater_d_fifo_full[geni]), .high(), .almost_full()
           , .rden(updater_d_fifo_ack)
           , .dout({current_pulse_t1_d[geni], current_pulse_dt_d[geni]
                  , current_pulse_in_idx_d[geni]
                  , current_pulse_dye_d[geni], current_pulse_zmw_number_d[geni]})
          , .empty(updater_d_fifo_empty[geni]), .almost_empty());

      better_fifo#(.TYPE("FPandZMW"), .WIDTH(FP_SIZE+N_ZMW_SIZE)
                 , .DELAY(DELAY))
      intensity_d_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
           , .wren(pulse_desc_valid_d[0])//updater_d_fifo_ack delayed
           //because the looked up intensity value from BRAM is delayed 1 clk
           , .din({current_pulse_intensity[geni], current_pulse_zmw_number_dd})
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

    better_fifo#(.TYPE("DYEandZMW")
	            , .WIDTH(MAX_PULSE_PER_ZMW*DYE_SIZE+N_ZMW_SIZE+1)
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

    better_fifo#(.TYPE("DYEandZMW")
	             , .WIDTH(MAX_PULSE_PER_ZMW*DYE_SIZE+N_ZMW_SIZE+1)
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
      pulse_to_ram_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .din({pulse_to_ram_fifo_data, pulse_to_ram_fifo_header[geni]})
                , .wren(pulse_to_ram_fifo_wren[geni])
                , .full(pulse_to_ram_fifo_full[geni])
                , .almost_full(pulse_to_ram_fifo_almost_full[geni])
                , .high(pulse_to_ram_fifo_high[geni])
                , .rden(pulse_to_ram_fifo_ack[geni])
                , .dout(pulse_to_ram_fifo_dout[geni])
                , .empty(pulse_to_ram_fifo_empty[geni])
                , .almost_empty(pulse_to_ram_fifo_almost_empty[geni]));

      assign #DELAY pulse_to_ram_fifo_ack[geni] = pulse_to_ram_fifo_valid[geni] &&
`ifdef STRAIGHTFORWARD_TO_PULSE_RAM_FIFIO_ACK
          (pulse_ram_state[geni] == PULSE_RAM_IDLE
        || pulse_ram_state[geni] == PULSE_RAM_MSG_WAIT1
        || (pulse_ram_state[geni] == PULSE_RAM_MSG_WAIT2 && //6
            pulse_to_ram_fifo_dout[geni][0] == `FALSE)//control message
        || (pulse_ram_state[geni] == PULSE_RAM_WR1 && //5
            (pulse_to_ram_fifo_dout[geni][0] == `FALSE ||//control message
             pulse_ram_wdf_rdy[geni]))
        || (pulse_ram_state[geni] == PULSE_RAM_WR2)
        || (pulse_ram_state[geni] == PULSE_RAM_READING)
        || (pulse_ram_state[geni] == PULSE_RAM_THROTTLED));
`else
        !((pulse_ram_state[geni] == PULSE_RAM_MSG_WAIT2 && pulse_to_ram_fifo_dout[geni][0]) ||
          (pulse_ram_state[geni] == PULSE_RAM_WR_WAIT) ||
          (pulse_ram_state[geni] == PULSE_RAM_WR1 && pulse_to_ram_fifo_dout[geni][0] && //is data
           !pulse_ram_wdf_rdy[geni]));
`endif

      bram256x128//BRAM to fake 256 bit DDR3 SODIMM for 128 ZMWs
      pulse_ram(.clka(CLK), .douta(pulse_ram_rd_data[geni])
              , .addra(pulse_ram_addr[geni]), .dina(pulse_ram_wdf_data)
              , .wea(pulse_ram_wdf_wren[geni]));
    end//for Ping-Pong RAM/////////////////////////////////////////////

    if(SIMULATION)
      PULSE_BRAM//this is not going to meet timing, so use only for verification
      pulse_rom(.clka(CLK), .douta(pulse_rom_rd_data), .addra(pulse_rom_addr));
    else
      assign pulse_rom_rd_data = {RAM_DATA_SIZE{`FALSE}};
  endgenerate

  localparam MSG_HEADER_TYPE_BIT = 0
           , CONTROL_MSG_START_BIT = 3
           , CONTROL_MSG_N_FRAME_BIT = 8, CONTROL_MSG_N_FRAME_SIZE = 24
           , CONTROL_MSG_N_CLOCK_PER_FRAME_BIT = CONTROL_MSG_N_FRAME_BIT
                                               + CONTROL_MSG_N_FRAME_SIZE
           , CONTROL_MSG_N_CLOCK_PER_FRAME_SIZE = 24
           , CONTROL_MSG_STRIDE_BIT = CONTROL_MSG_N_CLOCK_PER_FRAME_BIT
                                    + CONTROL_MSG_N_CLOCK_PER_FRAME_SIZE
           , CONTROL_MSG_STRIDE_SIZE = 8
           , CONTROL_MSG_EXPOSURE_BIT = CONTROL_MSG_STRIDE_BIT
                                      + CONTROL_MSG_STRIDE_SIZE
           , CONTROL_MSG_EXPOSURE_SIZE = FP_SIZE
           , PULSE_INTENSITY_INDEX_SIZE = 4;
  wire is_control_msg, is_start_msg, is_stop_msg, is_pulse_msg;
  //A PC message is either a camera control message (START/STOP; see design doc)
  //or data (pulse description) message
  assign #DELAY is_control_msg = pprojector_msg_valid
                              && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE;
  assign #DELAY is_start_msg = pprojector_msg_valid
             && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE//control msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `TRUE;//start msg
  assign #DELAY is_stop_msg = pprojector_msg_valid
             && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE//control msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE;//stop msg

  localparam PULSE_DESC_SIZE = FP_SIZE + FP_SIZE //t1, duration
                             + PULSE_INTENSITY_INDEX_SIZE
                             + DYE_SIZE + N_ZMW_SIZE;
  wire[FP_SIZE-1:0] new_pulse_t1, new_pulse_dt;
  wire[DYE_SIZE-1:0]  new_pulse_dye;
  wire[PULSE_INTENSITY_INDEX_SIZE-1:0] new_pulse_intensity;
  wire[N_ZMW_SIZE-1:0] new_pulse_zmw_num;
  assign #DELAY is_pulse_msg = pprojector_msg_valid
                            && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `TRUE;
  wire assembler2updater_fifo_ack, assembler2updater_fifo_full
     , assembler2updater_fifo_empty;

  better_fifo#(.TYPE("Pulse"), .WIDTH(PULSE_DESC_SIZE), .DELAY(DELAY))
  assembler2updater_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .wren(is_pulse_msg && !assembler2updater_fifo_full)
                , .din(whole_pc_msg[CONTROL_MSG_START_BIT+:PULSE_DESC_SIZE])
                , .high(), .full(assembler2updater_fifo_full), .almost_full()
                , .rden(assembler2updater_fifo_ack)
                , .dout({new_pulse_t1, new_pulse_dt, new_pulse_intensity
                       , new_pulse_dye, new_pulse_zmw_num})
                , .empty(assembler2updater_fifo_empty), .almost_empty());

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

  // FIFO from the pulse projector to the photonic tracer
  localparam KT_TRACE_SIZE = 1 + N_ZMW_SIZE + N_DYE*FP_SIZE;
  wire kt_fifo_overflow, kt_fifo_high, kt_fifo_full, kt_fifo_empty;
  wire[FP_SIZE-1:0] kinetic_trace[N_DYE-1:0];
  reg [FP_SIZE-1:0] ktrace[N_DYE-1:0];
  wire[N_ZMW_SIZE-1:0] kinetic_trace_zmw;
  wire kinetic_trace_xof, kt_fifo_ack;
  reg kt_fifo_wren, xof_dd_r;

  better_fifo#(.TYPE("KineticTrace"), .WIDTH(KT_TRACE_SIZE), .DELAY(DELAY))
  kt_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
        , .din({strength012[3], strength012[2], strength012[1], strength012[0]
              , pulse_dye_zmw_d, xof_dd})
        , .wren(zmwxof_d_fifo_ack), .full(kt_fifo_full)
        , .overflow(kt_fifo_overflow), .almost_full(), .high(kt_fifo_high)
        , .rden(kt_fifo_ack), .empty(kt_fifo_empty), .almost_empty()
        , .dout({kinetic_trace[3], kinetic_trace[2]
               , kinetic_trace[1], kinetic_trace[0]
               , kinetic_trace_zmw, kinetic_trace_xof}));

  //pprojector sequential logic /////////////////////////////////////////
  always @(posedge CLK) begin
    current_pulse_zmw_number_dd <= #DELAY current_pulse_zmw_number_d[0];
    
    pulse_desc_valid_d[0] <= #DELAY updater_d_fifo_ack;
    for(j=1; j < FCOMP_LATENCY; j=j+1)
      pulse_desc_valid_d[j] <= #DELAY pulse_desc_valid_d[j-1];

    for(i=0; i < MAX_PULSE_PER_ZMW; i=i+1) begin
      //current_pulse_intensity[i] <= #DELAY
      //  pulse_intensity_pool[current_pulse_in_idx_d[i]];

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

    //downstream_wren <= #DELAY zmwxof_d_fifo_ack;
    //downstream_din <= #DELAY {strength012[0]
    //                  , 2'b00, pulse_dye_zmw_d, 3'b000, xof_dd, pacer_state};

    pulse_from_ram_fifo_wren <= #DELAY pulse_ram_rd_data_valid[pulse_from_ram_src];

    //Delay to avoid weird FIFO timing
    kt_fifo_wren <= #DELAY zmwxof_d_fifo_ack;
    pulse_dye_zmw_r <= #DELAY pulse_dye_zmw_d;
    xof_dd_r <= #DELAY xof_dd;
    for(i=0; i <N_DYE; i=i+1) ktrace[i] <= #DELAY strength012[i];
    
    pulse_rom_addr <= #DELAY 0;//default to the beginning of the ROM
    
    if(RESET) begin
      gTime_cal_en <= #DELAY `FALSE;
      pacer_state <= #DELAY PACER_STOPPED;
      for(i=0; i<2; i=i+1) begin
        pulse_ram_en[i] <= #DELAY `FALSE;
        pulse_ram_read[i] <= #DELAY `FALSE;    
        pulse_to_ram_fifo_header[i] <= #DELAY 0;
        pulse_to_ram_fifo_wren[i] <= #DELAY `FALSE;
        pulse_ram_wdf_wren[i] <= #DELAY `FALSE;
        pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
      end
      pulse_from_ram_src <= #DELAY `FALSE;
    end else begin

      pulse_ram_en_and_read[0] <= #DELAY pulse_ram_en & pulse_ram_read;//bitwise
      for(i=1; i<OUTPUT_REGISTERED_BRAM_READ_LATENCY-1; i=i+1)
        pulse_ram_en_and_read[i] <= #DELAY pulse_ram_en_and_read[i-1];
      pulse_ram_rd_data_valid
        <= #DELAY pulse_ram_en_and_read[OUTPUT_REGISTERED_BRAM_READ_LATENCY-2];
      pulse_from_ram_fifo_din <= #DELAY pulse_ram_rd_data[pulse_from_ram_src];
  
      //Pacer code ////////////////////////////////////////////////////
      gTime_cal_en <= #DELAY `FALSE;
      if(nframeXexp_rdy) gTime <= #DELAY nframeXexp;
      if(nframe_1Xexp_rdy) gTime_exposure <= #DELAY nframe_1Xexp;
      
      for(i=0; i<2; i=i+1) pulse_to_ram_fifo_wren[i] <= #DELAY `FALSE;

      if(kt_fifo_overflow) pacer_state <= #DELAY PACER_ERROR;
      else begin
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
              //fetch 1st initialization value; doing it earlier since 2 clk delay
              pulse_rom_addr <= #DELAY 1;
              pulse_to_ram_fifo_data <= #DELAY {PULSES_DESC_SIZE{`FALSE}};            
              pulse_to_ram_fifo_header[0][2:0] <= #DELAY 'b110;//START(WR)
              pulse_to_ram_fifo_wren[0] <= #DELAY `TRUE;

              pulse_wr_zmw <= #DELAY 0;
              pulse_from_ram_src <= #DELAY `TRUE;
              pacer_state <= #DELAY PACER_STARTING;
            end

          PACER_STOPPING:
            if(pulse_to_ram_fifo_full == 'b00) begin// ^STOP to both RAM controllers
              for(i=0; i<2; i=i+1) begin
                pulse_to_ram_fifo_header[i] <= #DELAY 'h00;
                pulse_to_ram_fifo_wren[i] <= #DELAY `TRUE;
              end
              pacer_state <= #DELAY PACER_STOPPED;
            end
          
          PACER_STARTING: begin
            n_frame <= #DELAY 0;
            n_stride <= #DELAY 0;
            if(!pulse_to_ram_fifo_full[0]) begin
              //writing 0 in this cycle, so write 1 next
              pulse_wr_zmw <= #DELAY pulse_wr_zmw + `TRUE;
              pulse_to_ram_fifo_wren[0] <= #DELAY `TRUE;
              pulse_to_ram_fifo_data <= #DELAY
                  {pulse_rom_rd_data[RAM_DATA_SIZE-1:32]
                 , {(24-log2(N_ZMW)){`FALSE}}, pulse_wr_zmw};
              //Indicate data message from now in the header
              pulse_to_ram_fifo_header[0] <= #DELAY 'h01;
              //fetch next initialization value; 2 clk delay
              pulse_rom_addr <= #DELAY pulse_rom_addr + `TRUE;
              gTime_cal_en <= #DELAY `TRUE;
              pacer_state <= #DELAY PACER_INIT;
            end
          end
          
          PACER_INIT:
            if(is_control_msg
               && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE) begin//STOP
              //I can't ^STOP message here because of the possibility of FIFO full
              pacer_state <= #DELAY PACER_STOPPING;//just move to STOPPING
            end else if(pulse_to_ram_fifo_full[0]) begin
              pulse_to_ram_fifo_wren[0] <= #DELAY `FALSE;
              pacer_state <= #DELAY PACER_INIT_THROTTLED;
            end else begin
              if(pulse_wr_zmw == N_ZMW % (2**log2(N_ZMW))
                 && !pulse_to_ram_fifo_full[0]) begin
                pulse_to_ram_fifo_header[0] <= #DELAY 'h00;// ^STOP to 1st RAM
                n_clock <= #DELAY 0;
                n_clock_throttled <= #DELAY 0;
                pacer_state <= #DELAY PACER_STARTING_FRAME;
              end else begin
                pulse_to_ram_fifo_data <= #DELAY
                    {pulse_rom_rd_data[RAM_DATA_SIZE-1:32]
                   , {(24-log2(N_ZMW)){`FALSE}}, pulse_wr_zmw};
                //fetch next initialization value; 1 clk delay
                pulse_rom_addr <= #DELAY pulse_rom_addr + `TRUE;
                pulse_wr_zmw <= #DELAY pulse_wr_zmw + `TRUE;            
              end
              pulse_to_ram_fifo_wren[0] <= #DELAY `TRUE;
            end
          
          PACER_INIT_THROTTLED:
            if(is_control_msg
               && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE) begin//STOP
              pacer_state <= #DELAY PACER_STOPPING;
            end else if(!pulse_to_ram_fifo_full[0]) begin
              pulse_to_ram_fifo_wren[0] <= #DELAY `TRUE;
              pacer_state <= #DELAY PACER_INIT;
            end
            
          PACER_STARTING_FRAME: begin
            n_clock <= #DELAY n_clock + `TRUE;
            //Wait for both FIFO to free up
            if(!pulse_to_ram_fifo_full) begin // ^START to both DRAM managers
              n_frame <= #DELAY n_frame + `TRUE;
              
              //Tell src RAM to start reading, and ~src RAM to start writing.
              //Note that the src appears flipped because flipping happens at the
              //next clock.
              pulse_from_ram_src <= ~pulse_from_ram_src; // flip the source
              pulse_to_ram_fifo_header[~pulse_from_ram_src] <= #DELAY 'b00000010;//^START(RD)
              pulse_to_ram_fifo_header[pulse_from_ram_src] <= #DELAY 'b00000110;//^START(WR)
              pulse_to_ram_fifo_wren <= #DELAY 'b11;
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
              if(current_pulse_zmw_number_d[0][0+:log2(N_ZMW)] != pulse_rd_zmw) begin
                // ^STOP to both RAM controllers
                for(i=0; i<2; i=i+1) begin
                  pulse_to_ram_fifo_header[i] <= #DELAY 'h00;
                  pulse_to_ram_fifo_wren[i] <= #DELAY `TRUE;
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
                  pulse_to_ram_fifo_data <= #DELAY {
                      current_pulse_t1_d[0], current_pulse_dt_d[0]
                    , current_pulse_t1_d[1], current_pulse_dt_d[1]
                    , current_pulse_t1_d[2], current_pulse_dt_d[2]
                    , 2'b00, current_pulse_dye_d[0], current_pulse_in_idx_d[0]
                    , 2'b00, current_pulse_dye_d[1], current_pulse_in_idx_d[1]
                    , 2'b00, current_pulse_dye_d[2], current_pulse_in_idx_d[2]
                    , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                end else begin // a new pulse has to be saved to the ALT RAM
                //Which slot to grab?
                  if(gTimeGTEcurrent_pulse_tf[0]) begin//pulse[0] is expired
                    pulse_to_ram_fifo_data <= #DELAY {
                        new_pulse_t1, new_pulse_dt
                      , current_pulse_t1_d[1], current_pulse_dt_d[1]
                      , current_pulse_t1_d[2], current_pulse_dt_d[2]
                      , 2'b00, new_pulse_dye, new_pulse_intensity
                      , 2'b00, current_pulse_dye_d[1], current_pulse_in_idx_d[1]
                      , 2'b00, current_pulse_dye_d[2], current_pulse_in_idx_d[2]
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else if(gTimeGTEcurrent_pulse_tf[1]) begin
                    //pulse[1] is expired => take slot 1
                    pulse_to_ram_fifo_data <= #DELAY {
                        current_pulse_t1_d[0], current_pulse_dt_d[0]
                      , new_pulse_t1, new_pulse_dt
                      , current_pulse_t1_d[2], current_pulse_dt_d[2]
                      , 2'b00, current_pulse_dye_d[0], current_pulse_in_idx_d[0]
                      , 2'b00, new_pulse_dye, new_pulse_intensity
                      , 2'b00, current_pulse_dye_d[2], current_pulse_in_idx_d[2]
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else if(gTimeGTEcurrent_pulse_tf[2]) begin
                    //pulse[2] is expired => take slot 2
                    pulse_to_ram_fifo_data <= #DELAY {
                        current_pulse_t1_d[0], current_pulse_dt_d[0]
                      , current_pulse_t1_d[1], current_pulse_dt_d[1]
                      , new_pulse_t1, new_pulse_dt
                      , 2'b00, current_pulse_dye_d[0], current_pulse_in_idx_d[0]
                      , 2'b00, current_pulse_dye_d[1], current_pulse_in_idx_d[1]
                      , 2'b00, new_pulse_dye, new_pulse_intensity
                      , 10'b00_0000_0000, current_pulse_zmw_number_d[0]};
                  end else begin
                    //full => can't update, don't ACK
                  end
                end //else: a new pulse definition has to be saved to ALT

                //Write the updated (could be the same as current) pulse
                //description to ALT; note that we always write in this state
                //unless there is an error
                pulse_to_ram_fifo_header[~pulse_from_ram_src] <= #DELAY 'h01; // is data
                pulse_to_ram_fifo_wren[~pulse_from_ram_src] <= #DELAY `TRUE;
                pulse_rd_zmw <= #DELAY pulse_rd_zmw + `TRUE;
                
                if(pulse_rd_zmw == N_ZMW-1) begin // done checking
                  // ^STOP to RAM[src]
                  pulse_to_ram_fifo_header[pulse_from_ram_src] <= #DELAY 'b0000_0000;
                  pulse_to_ram_fifo_wren[pulse_from_ram_src] <= #DELAY `TRUE;
                  pacer_state <= #DELAY PACER_STOPPING_FRAME;
                end else if(pulse_to_ram_fifo_high[~pulse_from_ram_src]
                            || kt_fifo_high) begin
                  pacer_state <= #DELAY PACER_FRAME_THROTTLED;
                end//!if(pulse_rd_zmw == N_ZMW-1)

              end //else: not an error condition
            end //Can update pulse, and current pulse definition is ready
          end //case PACER_FRAME
          
          PACER_FRAME_THROTTLED: begin//delayed Tf calculation will keep coming
            //for PULSE_EXPIRATION_DETERMINATION_LATENCY after entry
            n_clock <= #DELAY n_clock + `TRUE;
            n_clock_throttled <= #DELAY n_clock_throttled + `TRUE;
            
            if(!(pulse_to_ram_fifo_high[~pulse_from_ram_src] || kt_fifo_high))
            begin //The default logic,
              n_clock_throttled <= #DELAY 0;
              pacer_state <= #DELAY PACER_FRAME;
            end//which may be overridden by valid current pulse definition below
            
            if(n_clock_throttled < PULSE_EXPIRATION_DETERMINATION_LATENCY
               && gTimeGTEcurrent_pulse_tf_rdy[0]
               && !updater_d_fifo_empty[0]) begin//consume comparison result
              //First, check the delayed answer
              if(current_pulse_zmw_number_d[0][0+:log2(N_ZMW)] != pulse_rd_zmw) begin
                // ^STOP to both RAM controllers
                for(i=0; i<2; i=i+1) begin
                  pulse_to_ram_fifo_header[i] <= #DELAY 'h00;
                  pulse_to_ram_fifo_wren[i] <= #DELAY `TRUE;
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
                  pulse_to_ram_fifo_data <= #DELAY {
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
                    pulse_to_ram_fifo_data <= #DELAY {
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
                    pulse_to_ram_fifo_data <= #DELAY {
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
                    pulse_to_ram_fifo_data <= #DELAY {
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
                pulse_to_ram_fifo_header[~pulse_from_ram_src] <= #DELAY 'h01; // is data
                pulse_to_ram_fifo_wren[~pulse_from_ram_src] <= #DELAY `TRUE;
                pulse_rd_zmw <= #DELAY pulse_rd_zmw + `TRUE;

                if(pulse_rd_zmw == N_ZMW-1) begin // done checking
                  // ^STOP to RAM[src]
                  pulse_to_ram_fifo_header[pulse_from_ram_src] <= #DELAY 'b0000_0000;
                  pulse_to_ram_fifo_wren[pulse_from_ram_src] <= #DELAY `TRUE;
                  pacer_state <= #DELAY PACER_STOPPING_FRAME;
                end//!if(pulse_rd_zmw == N_ZMW-1)
              end //else: not an error condition
            end//valid current pulse definition
          end//PACER_FRAME_THROTTLED

          PACER_STOPPING_FRAME: begin
            n_clock <= #DELAY n_clock + `TRUE;
            //^EOF
            if(n_frame == max_frame) pacer_state <= #DELAY PACER_STOPPING;
            else if(!pulse_to_ram_fifo_full[~pulse_from_ram_src]) begin
              //^STOP to RAM[~src]
              pulse_to_ram_fifo_header[~pulse_from_ram_src] <= #DELAY 'b0000_0000;
              pulse_to_ram_fifo_wren[~pulse_from_ram_src] <= #DELAY `TRUE;
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
            pulse_to_ram_fifo_wren <= #DELAY {`FALSE, `FALSE};
          end
        endcase//pacer_state
      end //!downstream_overflow
      
      // DRAM manager code /////////////////////////////////////////////
      for(i=0; i<2; i=i+1) begin // Dual RAM => dual statemachine
        //pulse_to_ram_fifo_ack[i] <= #DELAY `FALSE;//don't ACK by default
        pulse_ram_wdf_end[i] <= #DELAY `FALSE;
        
        case(pulse_ram_state[i])
          PULSE_RAM_IDLE: begin
            pulse_ram_addr[i] <= #DELAY 0;
            if(pulse_to_ram_fifo_valid[i]) begin              
              if(pulse_to_ram_fifo_dout[i][0] == `FALSE //control message
                 && pulse_to_ram_fifo_dout[i][1] == `TRUE) begin //SOF
                if(pulse_to_ram_fifo_dout[i][2] == `TRUE) begin
                  pulse_ram_en[i] <= #DELAY `FALSE;
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_MSG_WAIT1;
                end else begin
                  pulse_ram_read[i] <= #DELAY `TRUE;
                  pulse_ram_en[i] <= #DELAY `TRUE;
                  pulse_rd_zmw <= #DELAY 0;
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_READING;
                end
              end
              
              //pulse_to_ram_fifo_ack[i] <= #DELAY `TRUE;
            end
          end

          PULSE_RAM_MSG_WAIT1:
            if(pulse_to_ram_fifo_valid[i]) begin
              if(pulse_to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
                if(pulse_to_ram_fifo_dout[i][1] == `FALSE) begin //EOF
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
                end//If SOF, just ignore, since RAM is in SAVING state already
              end else begin//There is at least 1 data
                pulse_to_ram_cache[i] <= #DELAY pulse_to_ram_fifo_dout[i];
                pulse_ram_state[i] <= #DELAY PULSE_RAM_MSG_WAIT2;
              end
              
              //pulse_to_ram_fifo_ack[i] <= #DELAY `TRUE;
            end
            
          PULSE_RAM_MSG_WAIT2:
            if(pulse_to_ram_fifo_valid[i]) begin
              if(pulse_to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
                if(pulse_to_ram_fifo_dout[i][1] == `FALSE) begin //EOF
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
                end//If SOF, just ignore, since RAM is in SAVING state already
                //pulse_to_ram_fifo_ack[i] <= #DELAY `TRUE; //ACK the control msg
              end else begin//There 1 more data at the head of FIFO; don't pop
                //begin the burst write
                pulse_ram_read[i] <= #DELAY `FALSE;
                pulse_ram_en[i] <= #DELAY `TRUE;
                pulse_ram_state[i] <= #DELAY PULSE_RAM_WR_WAIT;
              end
            end

          PULSE_RAM_WR_WAIT: //wait for the HW to grant write
            if(pulse_ram_rdy[i] && pulse_ram_wdf_rdy[i]) begin
              pulse_ram_wdf_data <= #DELAY pulse_to_ram_cache[i];//first write the stored
              // Write at the current pulse_ram_addr[i]
              pulse_ram_wdf_wren[i] <= #DELAY `TRUE;
              pulse_ram_state[i] <= #DELAY PULSE_RAM_WR1;
            end
          
          PULSE_RAM_WR1://HW writing the 1st of the pair in this state
            //We transitioned to this state because there IS message in FIFO
            //But is it a control message?
            if(pulse_to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
              if(pulse_to_ram_fifo_dout[i][1] == `FALSE) begin //EOF
                pulse_ram_en[i] <= #DELAY `FALSE;//turn things off by default
                //abandon the information in pulse_to_ram_cache
                pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
              end//If SOF, just ignore, since RAM is in SAVING state already
              //pulse_to_ram_fifo_ack[i] <= #DELAY `TRUE; //ACK the control msg
            end else if(pulse_ram_wdf_rdy[i]) begin//always TRUE for BRAM
              //we are here because there IS data in FIFO
              pulse_ram_wdf_data <= #DELAY pulse_to_ram_fifo_dout[i];//get it now
              pulse_ram_wdf_end[i] <= #DELAY `TRUE;
              pulse_ram_wdf_wren[i] <= #DELAY `TRUE;//write the 2nd data
              pulse_ram_addr[i] <= #DELAY pulse_ram_addr[i] + RAM_ADDR_INCR;//move pointer
              //pulse_to_ram_fifo_ack[i] <= #DELAY `TRUE;//and acknowledge data
              pulse_ram_state[i] <= #DELAY PULSE_RAM_WR2;
            end
            
          PULSE_RAM_WR2: begin//HW writing the 2nd of the pair in this state
            pulse_ram_en[i] <= #DELAY `FALSE;//turn things off by default
            pulse_ram_wdf_wren[i] <= #DELAY `FALSE;

            //What to do next?
            if(pulse_to_ram_fifo_valid[i]) begin //There IS a message from pacer
              if(pulse_to_ram_fifo_dout[i][0] == `FALSE) begin//control msg
                if(pulse_to_ram_fifo_dout[i][1] == `FALSE) begin//EOF/STOP
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
                end else begin// SOF => ignore
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_MSG_WAIT1;
                end
              end else begin // there is DATA, but how many?
                //Since I just wrote (the 2nd of the burst), I have to increment
                //address for the future write
                pulse_ram_addr[i] <= #DELAY pulse_ram_addr[i] + RAM_ADDR_INCR;
                
                pulse_to_ram_cache[i] <= #DELAY pulse_to_ram_fifo_dout[i];//save the 1st
                if(pulse_to_ram_fifo_almost_empty[i]) begin
                  //just 1 message => don't write; wait for 2nd
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_MSG_WAIT2;
                end else begin//there are 2 messages => can burst
                  pulse_ram_en[i] <= #DELAY `TRUE;
                  if(pulse_ram_wdf_rdy[i]) begin //HW already ready to write =>
                    //no clock cycle to save to cache => just grab what's in FIFO
                    pulse_ram_wdf_data <= #DELAY pulse_to_ram_fifo_dout[i];
                    pulse_ram_wdf_wren[i] <= #DELAY `TRUE;
                    //pulse_ram_addr[i] <= #DELAY pulse_ram_addr[i] + RAM_ADDR_INCR;
                    pulse_ram_state[i] <= #DELAY PULSE_RAM_WR1;
                  end else begin//HW not ready
                    pulse_to_ram_cache[i] <= #DELAY pulse_to_ram_fifo_dout[i];//save away
                    pulse_ram_state[i] <= #DELAY PULSE_RAM_WR_WAIT;
                  end
                end
              end
              //pulse_to_ram_fifo_ack[i] <= #DELAY `TRUE;//acknowledge it
            end else begin// no message at all => wait for msg
              pulse_ram_state[i] <= #DELAY PULSE_RAM_MSG_WAIT1;
            end
          end

          PULSE_RAM_READING:
            if(pulse_to_ram_fifo_valid[i]//There IS a message from pacer
              && pulse_to_ram_fifo_dout[i][1:0] == 'b00) begin//STOP message
              pulse_ram_en[i] <= #DELAY `FALSE;
              pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
              //Ignore all other messages
              //Don't forget to ACK the message in combinational logic
            end else begin
              if(pulse_from_ram_fifo_full) begin
                pulse_ram_en[i] <= #DELAY `FALSE;
                pulse_ram_state[i] <= #DELAY PULSE_RAM_ERROR;
              end else if(pulse_from_ram_fifo_high) begin
                pulse_ram_en[i] <= #DELAY `FALSE;
                pulse_ram_state[i] <= #DELAY PULSE_RAM_THROTTLED;
              end else begin
                pulse_ram_addr[i] <= #DELAY pulse_ram_addr[i] + RAM_ADDR_INCR;
                if(pulse_ram_addr[i] == N_ZMW-1) begin
                  pulse_ram_en[i] <= #DELAY `FALSE;
                  pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
                end
              end
            end
          
          PULSE_RAM_THROTTLED:
            if(pulse_to_ram_fifo_valid[i]//There IS a message from pacer
              && pulse_to_ram_fifo_dout[i][1:0] == 'b00) begin//STOP message
              pulse_ram_en[i] <= #DELAY `FALSE;
              pulse_ram_state[i] <= #DELAY PULSE_RAM_IDLE;
              //Ignore all other messages
              //Don't forget to ACK the message in combinational logic
            end else begin
              if(pulse_from_ram_fifo_full) begin
                pulse_ram_en[i] <= #DELAY `FALSE;
                pulse_ram_state[i] <= #DELAY PULSE_RAM_ERROR;
              end else if(!pulse_from_ram_fifo_high) begin
                pulse_ram_en[i] <= #DELAY `TRUE;
                pulse_ram_state[i] <= #DELAY PULSE_RAM_READING;
              end
            end
          
          default: begin
          end
          
        endcase//pulse_ram_state[i]
      end//for(i)
    end//!RESET
  end//always @(posedge CLK)

  // Trace stage ///////////////////////////////////////////////////////
  reg zmw_msg_valid;//Is there a message from the PC to this logic?
  localparam N_CAM = 2
           , N_ROW = 16, CAM_ROW_SIZE = 12
           , N_COL = 128, CAM_COL_SIZE = 12;

  localparam ZMW_RAM_ERROR = 0
           , ZMW_RAM_MSG_WAIT = 1, ZMW_RAM_WR_WAIT = 2, ZMW_RAM_WR1 = 3
           , ZMW_RAM_WR2 = 4, ZMW_RAM_READING = 5, ZMW_RAM_THROTTLED = 6
           , ZMW_RAM_N_STATE = 7;
  reg [log2(ZMW_RAM_N_STATE)-1:0] zmw_ram_state;

  // RAM interface
  wire zmw_ram_rdy, zmw_ram_wdf_rdy;
  reg  zmw_ram_en, zmw_ram_read, zmw_ram_wdf_wren, zmw_ram_wdf_end
     , zmw_ram_en_and_read[OUTPUT_REGISTERED_BRAM_READ_LATENCY-2:0]
     , zmw_ram_rd_data_valid;
  assign zmw_ram_rdy = `TRUE;
  assign zmw_ram_wdf_rdy = `TRUE;
  reg [log2(N_ZMW)-1:0] zmw_ram_addr, zmw_ram_n_read;
  wire[RAM_DATA_SIZE-1:0] zmw_ram_rd_data;
  reg [RAM_DATA_SIZE-1:0] zmw_ram_wdf_data;

  ZMW_BRAM//BRAM to fake 256 bit DDR3 SODIMM for 128 ZMWs
  zmw_ram(.clka(CLK), .douta(zmw_ram_rd_data), .addra(zmw_ram_addr)
        , .dina(zmw_ram_wdf_data), .wea(zmw_ram_wdf_wren));

  // FIFO from RAM to the photonic tracer
  wire zmw_from_ram_fifo_ack, zmw_from_ram_fifo_empty, zmw_from_ram_fifo_valid
     , zmw_from_ram_fifo_high, zmw_from_ram_fifo_full
     , zmw_from_ram_fifo_almost_full;
  localparam ZMW_RAM_META_SIZE = 16;
  wire[ZMW_RAM_META_SIZE-1:0] zmw_from_ram_fifo_meta;
  // register the inputs for timing margin
  reg  zmw_from_ram_fifo_wren;
  reg [RAM_DATA_SIZE-1:0] zmw_from_ram_fifo_din;
  
  localparam SMALL_FP_SIZE = 24;
  wire[CAM_ROW_SIZE-1:0] zmw_from_ram_pixel_row, ctrace_row;
  wire[CAM_COL_SIZE-1:0] zmw_from_ram_pixel_col, ctrace_col;
  wire[7:0] zmw_from_ram_fsp_idx[N_CAM-1:0], zmw_from_ram_spectral_mx_idx;
  wire[SMALL_FP_SIZE-1:0] zmw_from_ram_photonic_bias[N_DYE-1:0]
                        , zmw_from_ram_photonic_gain[N_DYE-1:0];
  localparam PTRACER_ERROR = 0, PTRACER_INITIALIZING = 1, PTRACER_RUNNING = 2
           , PTRACER_N_STATE = 3;
  reg [log2(PTRACER_N_STATE)-1:0] ptracer_state;
  
  better_fifo#(.TYPE("FromRAM"), .WIDTH(RAM_DATA_SIZE), .DELAY(DELAY))
  zmw_from_ram_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
      , .wren(zmw_from_ram_fifo_wren), .din(zmw_from_ram_fifo_din)
      , .high(zmw_from_ram_fifo_high), .full(zmw_from_ram_fifo_full)
      , .almost_full(zmw_from_ram_fifo_almost_full)
      , .overflow(zmw_from_ram_fifo_overflow)
      , .rden(zmw_from_ram_fifo_ack)
      , .dout({zmw_from_ram_pixel_row, zmw_from_ram_pixel_col
             , zmw_from_ram_fsp_idx[0], zmw_from_ram_fsp_idx[1]
             , zmw_from_ram_spectral_mx_idx
             , zmw_from_ram_photonic_bias[0], zmw_from_ram_photonic_gain[0]
             , zmw_from_ram_photonic_bias[1], zmw_from_ram_photonic_gain[1]
             , zmw_from_ram_photonic_bias[2], zmw_from_ram_photonic_gain[2]
             , zmw_from_ram_photonic_bias[3], zmw_from_ram_photonic_gain[3]
             , zmw_from_ram_fifo_meta})
      , .empty(zmw_from_ram_fifo_empty), .almost_empty());
  assign zmw_from_ram_fifo_valid = !zmw_from_ram_fifo_empty;

  //Delaying the ack throws off simulation timing
  assign zmw_from_ram_fifo_ack = ptracer_state
    && !(zmw_from_ram_fifo_empty
         || kt_fifo_empty || kinetic_trace_xof || zmw_rowcol_d_fifo_high);
  assign kt_fifo_ack = ptracer_state && !kt_fifo_empty &&
    (kinetic_trace_xof || !zmw_from_ram_fifo_empty)
    && !zmw_rowcol_d_fifo_high;

  localparam FSP_HEIGHT = 3, FSP_WIDTH = 6;
  //See Figure "Kinetic and camera trace processing flow" in design doc
  wire[FP_SIZE-1:0] ktXgain[N_DYE-1:0], photonic_trace[N_DYE-1:0]
                  , ptXinvsp[N_CAM-1:0][N_DYE-1:0]
                  , ctrace_p[N_CAM-1:0][N_DYE/2-1:0]//1st stage add result
                  , cam_trace[N_CAM-1:0]//final add result
                  , ctrace[N_CAM-1:0];//output of the ctrace_fifo
  wire[N_CAM-1:0] cam_trace_rdy
                , ctrace_fifo_empty, ctrace_fifo_high, ctrace_fifo_ack;
  wire[N_DYE/2-1:0] ctrace_p_rdy[N_CAM-1:0];
  reg [SMALL_FP_SIZE-1:0] inv_dye_mx_din, fsp_mx_din;
  wire[SMALL_FP_SIZE-1:0] photonic_bias[N_DYE-1:0]
                        , inv_dye_mx_dout[N_CAM-1:0][N_DYE-1:0]
                        , inv_dye_mx[N_CAM-1:0][N_DYE-1:0]
                        , fsp_mx_dout[N_CAM-1:0][FSP_HEIGHT-1:0][FSP_WIDTH-1:0];
  wire[N_DYE-1:0] photonic_bias_d_fifo_empty, photonic_bias_d_fifo_full
                , ktXgain_rdy, photonic_trace_rdy
                , inv_dye_mx_fifo_empty[N_CAM-1:0]
                , ptXinvsp_rdy[N_CAM-1:0];
  reg [N_DYE-1:0] inv_dye_mx_wren[N_CAM-1:0];
  reg [OUTPUT_REGISTERED_BRAM_READ_LATENCY:0] zmw_from_ram_fifo_ack_d;
  reg [7:0] inv_dye_mx_addr;//, fsp_mx_addr[N_CAM-1:0];
  wire[7:0] fsp_idx[N_CAM-1:0];
  reg [FSP_WIDTH-1:0] fsp_mx_wren[N_CAM-1:0][FSP_HEIGHT-1:0];
  wire[FSP_WIDTH-1:0] fsp_mx_fifo_empty[N_CAM-1:0][FSP_HEIGHT-1:0];

  //Delayed output of the tracer logic
  reg ctrace_valid_d, ctrace_commit_d, ctrace_xof_d;
  reg [FP_SIZE-1:0] ctrace_d[N_CAM-1:0];
  reg [CAM_ROW_SIZE-1:0] ctrace_row_d;
  reg [CAM_COL_SIZE-1:0] ctrace_col_d;
  reg [N_ZMW_SIZE-1:0] ctrace_zmw_d;

  generate
    for(geni=0; geni < N_DYE; geni=geni+1) begin
      fmult ktXgain_module(.clk(CLK), .sclr(RESET)
          , .operation_nd(zmw_from_ram_fifo_ack), .a(kinetic_trace[geni])
          , .b({zmw_from_ram_photonic_gain[geni], 8'h00})
          , .result(ktXgain[geni]), .rdy(ktXgain_rdy[geni]));
    
      better_fifo#(.TYPE("SmallFP"), .WIDTH(SMALL_FP_SIZE), .DELAY(DELAY))
      photonic_bias_d_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
          , .din(zmw_from_ram_photonic_bias[geni])
          , .wren(zmw_from_ram_fifo_ack)
          , .full(photonic_bias_d_fifo_full[geni]), .high(), .almost_full()
          , .rden(ktXgain_rdy[geni]), .dout(photonic_bias[geni])
          , .empty(photonic_bias_d_fifo_empty[geni]), .almost_empty());

      fadd add_photonic_bias(.clk(CLK), .sclr(RESET)
          , .operation_nd(ktXgain_rdy[geni]), .a(ktXgain[geni])
          , .b({photonic_bias[geni]
              , {(FP_SIZE-SMALL_FP_SIZE){`FALSE}}})//Append missing LSB
          , .result(photonic_trace[geni]), .rdy(photonic_trace_rdy[geni]));
    end//for(N_DYE)

    for(geni=0; geni < N_CAM; geni=geni+1) begin
      for(genj=0; genj < N_DYE; genj=genj+1) begin
        //The inverse spectral mx pool is organized as [sensor][channel][index].  
        //That is, contribution of pulse channel j to i sensor.  So when you
        //specify the inv spectral mx index for a ZMW (again, time invariant),
        //the contribution of the i channel on j camera is fixed
        bram24x256 inv_dye_mx_bram(.clka(CLK), .wea(inv_dye_mx_wren[geni][genj])
          , .addra(inv_dye_mx_addr), .dina(inv_dye_mx_din)
          , .douta(inv_dye_mx_dout[geni][genj]));

        better_fifo#(.TYPE("SmallFP"), .WIDTH(SMALL_FP_SIZE), .DELAY(DELAY))
        inv_dye_mx_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
          , .din(inv_dye_mx_dout[geni][genj])
          //Extra clock delay, because inv_dye_mx_addr above is registered
          , .wren(zmw_from_ram_fifo_ack_d[0])
          , .full(), .high(), .almost_full()
          , .rden(photonic_trace_rdy[genj])//consume ISM when ptrace rdy
          , .dout(inv_dye_mx[geni][genj])
          , .empty(inv_dye_mx_fifo_empty[geni][genj]), .almost_empty());

        //When you have the inv_dye_mx, can multiply against the photonic_trace
        fmult ptraceXinvsp_module(.clk(CLK), .sclr(RESET)
          , .operation_nd(photonic_trace_rdy[genj]), .a(photonic_trace[genj])
          , .b({inv_dye_mx[geni][genj]
              , {(FP_SIZE-SMALL_FP_SIZE){`FALSE}}})//Append missing LSB
          , .result(ptXinvsp[geni][genj]), .rdy(ptXinvsp_rdy[geni][genj]));
      end//for(N_DYE)

      for(genj=0; genj < N_DYE/2; genj=genj+1)begin
        //1st stage addition for camera trace: "t" + "g", or "a" + "c"
        fadd add_ptXinvsp(.clk(CLK), .sclr(RESET)
            , .operation_nd(ptXinvsp_rdy[geni][2*genj])
            , .a(ptXinvsp[geni][2*genj]), .b(ptXinvsp[geni][2*genj+1])
            , .result(ctrace_p[geni][genj]), .rdy(ctrace_p_rdy[geni][genj]));
      end//for(N_DYE/2)
      
      //Note: programming Verilog to put in possible additional stages is probably
      //possible, but given that N_DYE = 4 is pretty much written in stone, just
      //not necessary
      
      //last stage addition for ctrace: ("t" + "g") + ("a" + "c")
      fadd add_ctrace_p(.clk(CLK), .sclr(RESET)
          , .operation_nd(ctrace_p_rdy[geni][0])
          , .a(ctrace_p[geni][0]), .b(ctrace_p[geni][1])
          , .result(cam_trace[geni]), .rdy(cam_trace_rdy[geni]));

      //downstream may throttle, so need a FIFO to buffer and throttle upstream
      better_fifo#(.TYPE("FP"), .WIDTH(FP_SIZE), .DELAY(DELAY))
      ctrace_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .wren(cam_trace_rdy[geni]), .din(cam_trace[geni])
                , .high(ctrace_fifo_high[geni]), .full(), .almost_full()
                , .rden(ctrace_fifo_ack[geni]), .dout(ctrace[geni])
                , .empty(ctrace_fifo_empty[geni]), .almost_empty());

      assign ctrace_fifo_ack[geni] = !ctrace_fifo_empty[geni]
        && (ctrace_row < ctp_can_accept_row
            || (ctrace_row == ctp_can_accept_row
                && ctrace_col <= ctp_can_accept_col));

      for(genj=0; genj<FSP_HEIGHT; genj=genj+1) begin
        for(genk=0; genk<FSP_WIDTH; genk=genk+1) begin
          bram24x256 fsp_mx_bram(.clka(CLK), .wea(fsp_mx_wren[geni][genj][genk])
            , .addra(fsp_idx[geni]), .dina(fsp_mx_din)
            , .douta(fsp_mx_dout[geni][genj][genk]));

`ifdef LOOKUP_FSP_EARLY
          better_fifo#(.TYPE("SmallFP"), .WIDTH(SMALL_FP_SIZE), .DELAY(DELAY))
          fsp_mx_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
            , .din(fsp_mx_dout[geni][genj][genk])
            , .wren(zmw_from_ram_fifo_ack_d[OUTPUT_REGISTERED_BRAM_READ_LATENCY-1])
            , .full(), .high(), .almost_full()
            , .rden(), .dout(fsp_mx[geni][genj][genk])
            , .empty(fsp_mx_fifo_empty[geni][genj][genk]), .almost_empty());
`endif//LOOKUP_FSP_EARLY

        end //for(FSP_WIDTH)
      end //for(FSP_HEIGHT)
     end//for(N_CAM)      
  endgenerate

  wire[SMALL_FP_SIZE-2*8-1:0] fps_index_fifo_bitbucket;
  wire fsp_idx_fifo_empty, fsp_idx_fifo_full, fsp_idx_fifo_high
     , fsp_idx_fifo_ack;
  
  better_fifo#(.TYPE("SmallFP"), .WIDTH(SMALL_FP_SIZE), .DELAY(DELAY))
  fsp_idx_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
      , .din({{(SMALL_FP_SIZE-2*8){`FALSE}}
            , zmw_from_ram_fsp_idx[1], zmw_from_ram_fsp_idx[0]})
      , .wren(zmw_from_ram_fifo_ack)
      , .full(fsp_idx_fifo_full), .high(fsp_idx_fifo_high), .almost_full()
      , .rden(fsp_idx_fifo_ack)
      , .dout({fps_index_fifo_bitbucket, fsp_idx[1], fsp_idx[0]})
      , .empty(fsp_idx_fifo_empty), .almost_empty());

  wire[N_ZMW_SIZE-1:0] ctrace_zmw;
  wire ctrace_xof, zmw_rowcol_d_fifo_high, zmw_rowcol_d_fifo_empty;
  wire[FP_SIZE-CAM_ROW_SIZE-CAM_COL_SIZE-2:0] zmw_rowcol_d_fifo_bitbucket;
  wire zmw_rowcol_d_fifo_ack;
  
  better_fifo#(.TYPE("FPandZMW"), .WIDTH(FP_SIZE+N_ZMW_SIZE), .DELAY(DELAY))
  zmw_rowcol_d_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                  , .wren(kt_fifo_ack)
                  , .din({{(FP_SIZE-CAM_ROW_SIZE-CAM_COL_SIZE-1){`FALSE}}
                        , zmw_from_ram_pixel_row, zmw_from_ram_pixel_col
                        , kinetic_trace_zmw, kinetic_trace_xof})
                  , .high(zmw_rowcol_d_fifo_high), .full(), .almost_full()
                  , .rden(zmw_rowcol_d_fifo_ack)
                  , .dout({zmw_rowcol_d_fifo_bitbucket
                         , ctrace_row, ctrace_col, ctrace_zmw, ctrace_xof})
                  , .empty(zmw_rowcol_d_fifo_empty), .almost_empty());

  localparam CTP_ERROR = 0, CTP_INTERFRAME = 1, CTP_INTRAFRAME = 2
           , CTP_N_STATE = 3;
  reg [log2(CTP_N_STATE)-1:0] ctp_state;
  
  //See Figure "Kinetic and camera trace processing flow" in the design doc
  assign fsp_idx_fifo_ack = !fsp_idx_fifo_empty
    && ctrace_fifo_ack[0];//1 is the same as 0

  assign zmw_rowcol_d_fifo_ack = !zmw_rowcol_d_fifo_empty
      && (ctrace_xof || ctrace_fifo_ack[0]); //1 is the same as 0

  localparam N_CTPRS = 8;//Must be > FSP_WIDTH, and power of 2
  //wire signed[log2(N_CTPRS):0] avail_ctprs[FSP_HEIGHT-1:0];//extra sign bit
  reg [N_CTPRS-1:0] ctprs_init[FSP_HEIGHT-1:0], ctprs_ack[FSP_HEIGHT-1:0];
  reg [log2(N_CTPRS)-1:0] ctprs_to_init[FSP_HEIGHT-1:0]
                        , ctprs_to_ack[FSP_HEIGHT-1:0];
  wire[N_CTPRS-1:0] ctprs_done[FSP_HEIGHT-1:0], ctprs_avail[FSP_HEIGHT-1:0];
  wire[FP_SIZE-1:0] ctprs_result[FSP_HEIGHT-1:0][N_CTPRS-1:0]
                  , inter_fsp_row_fifo_dout[FSP_HEIGHT-1:0];;
  reg [FP_SIZE-1:0] inter_fsp_row_fifo_din[FSP_HEIGHT-1:0];
  reg [CAM_ROW_SIZE-1:0] ctprs_row[FSP_HEIGHT-1:0], ctp_can_accept_row;
  reg [CAM_COL_SIZE-1:0] ctprs_col[FSP_HEIGHT-1:0];
  reg signed [CAM_COL_SIZE:0] ctp_can_accept_col;
  reg [SMALL_FP_SIZE-1:0] pixel_bg;//TODO: initialize this FP from Xillybus

  reg [FSP_HEIGHT-1:0] inter_fsp_row_fifo_wren;
  wire[FSP_HEIGHT-1:0] inter_fsp_row_fifo_empty, inter_fsp_row_fifo_high
                     , inter_fsp_row_fifo_ack;

  generate
    for(geni=0; geni<FSP_HEIGHT; geni=geni+1) begin
      for(genj=0; genj<N_CTPRS; genj=genj+1) begin
        CameraTraceProjectionRowSummer#(.FSP_ROW(geni), .DELAY(DELAY)
          , .FP_SIZE(FP_SIZE), .SMALL_FP_SIZE(SMALL_FP_SIZE)
          , .N_CTPRS(N_CTPRS), .N_COL(N_COL), .N_CAM(N_CAM)
          , .CAM_ROW_SIZE(CAM_ROW_SIZE), .CAM_COL_SIZE(CAM_COL_SIZE)
          , .FSP_WIDTH(FSP_WIDTH))
        ctprs(.CLK(CLK), .RESET(RESET)
            , .init(ctprs_init[geni][genj])
            , .config_initial(geni == FSP_HEIGHT-1 ? pixel_bg
                                                   : inter_fsp_row_fifo_dout[i+1])
            , .config_row(ctprs_row[geni]), .config_col(ctprs_col[geni])
            , .ctrace_valid(ctrace_valid_d), .ctrace_commit(ctrace_commit_d)
            , .xof(ctrace_xof_d), .ctrace_row(ctrace_row_d), .ctrace_col(ctrace_col_d)
            , .grn_ctrace(ctrace_d[0]), .red_ctrace(ctrace_d[1])
            , .grn_fsp0(fsp_mx_dout[0][geni][0]), .grn_fsp1(fsp_mx_dout[0][geni][1])
            , .grn_fsp2(fsp_mx_dout[0][geni][2]), .grn_fsp3(fsp_mx_dout[0][geni][3])
            , .grn_fsp4(fsp_mx_dout[0][geni][4]), .grn_fsp5(fsp_mx_dout[0][geni][5])
            , .red_fsp0(fsp_mx_dout[1][geni][0]), .red_fsp1(fsp_mx_dout[1][geni][1])
            , .red_fsp2(fsp_mx_dout[1][geni][2]), .red_fsp3(fsp_mx_dout[1][geni][3])
            , .red_fsp4(fsp_mx_dout[1][geni][4]), .red_fsp5(fsp_mx_dout[1][geni][5])
            , .sum_ack(ctprs_init[geni][genj])
            , .available(ctprs_avail[geni][genj]), .done(ctprs_done[geni][genj])
            , .result(ctprs_result[geni][genj]));

`ifdef COMBINATIONAL_CTPRS_INIT
        assign ctprs_init[geni][genj] = ctp_state == CTP_INTRAFRAME
            && !(ctp_can_accept_row == N_ROW - FSP_HEIGHT
                 && ctp_can_accept_col == N_COL - FSP_WIDTH)//At the last pixel
            && ctprs_to_init[geni] == genj//This CTPRS is the one CTP wants
            && ctprs_avail[geni][genj];   //and it is available
`endif//COMBINATIONAL_CTPRS_INIT
      end//for(N_CTPRS)

      better_fifo#(.TYPE("FP"), .WIDTH(FP_SIZE), .DELAY(DELAY))
      inter_fsp_row_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .wren(inter_fsp_row_fifo_wren[geni])
                , .din(inter_fsp_row_fifo_din[geni])
                , .high(inter_fsp_row_fifo_high[geni]), .full(), .almost_full()
                , .rden(inter_fsp_row_fifo_ack[geni])
                , .dout(inter_fsp_row_fifo_dout[geni])
                , .empty(inter_fsp_row_fifo_empty[geni]), .almost_empty());
    end//for(FSP_HEIGHT)
      
  endgenerate

  always @(posedge CLK) begin //Trace domain sequential logic///////////////
    // Setup defaults
    zmw_ram_en_and_read[0] <= #DELAY zmw_ram_en & zmw_ram_read;
    for(i=1; i<OUTPUT_REGISTERED_BRAM_READ_LATENCY-1; i=i+1)
      zmw_ram_en_and_read[i] <= #DELAY zmw_ram_en_and_read[i-1];
    zmw_ram_rd_data_valid
      <= #DELAY zmw_ram_en_and_read[OUTPUT_REGISTERED_BRAM_READ_LATENCY-2];

    zmw_ram_wdf_end <= #DELAY `FALSE;
    zmw_from_ram_fifo_wren <= #DELAY `FALSE;
    zmw_ram_wdf_wren <= #DELAY `FALSE;
    
    zmw_from_ram_fifo_ack_d[0] <= #DELAY zmw_from_ram_fifo_ack;
    for(i=1; i<=OUTPUT_REGISTERED_BRAM_READ_LATENCY; i=i+1)
      zmw_from_ram_fifo_ack_d[i] <= #DELAY zmw_from_ram_fifo_ack_d[i-1];

    for(i=0; i<N_CAM; i=i+1)
      for(j=0; j<N_DYE; j=j+1)
        inv_dye_mx_wren[i][j] <= #DELAY `FALSE;
    
	  zmw_from_ram_fifo_din[RAM_DATA_SIZE-1:ZMW_RAM_META_SIZE] <= #DELAY
	     zmw_ram_rd_data[RAM_DATA_SIZE-1:ZMW_RAM_META_SIZE];

    //register ctrace and ZMW specific data for better timing
    ctrace_commit_d <= #DELAY ctrace_fifo_ack[0];
    ctrace_valid_d <= #DELAY !ctrace_fifo_empty[0];
    ctrace_xof_d <= #DELAY ctrace_xof && zmw_rowcol_d_fifo_ack;
    ctrace_zmw_d <= #DELAY ctrace_zmw;
    ctrace_row_d <= #DELAY ctrace_row;
    ctrace_col_d <= #DELAY ctrace_col;
    for(i=0; i<N_CAM; i=i+1) ctrace_d[i] <= #DELAY ctrace[i];

`ifdef DELAY_FSP
    for(i=0; i<N_CAM; i=i+1)
      for(j=0; j<FSP_HEIGHT; j=j+1)
        for(k=0; k<FSP_WIDTH; k=k+1)
          fsp_mx_d[i][j][k] <= #DELAY fsp_mx_dout[i][j][k];
`endif//DELAY_FSP

    for(i=0; i<FSP_HEIGHT; i=i+1) begin
      for(j=0; j<N_CTPRS; j=j+1) begin
       ctprs_ack[i][j] <= #DELAY `FALSE;
`ifndef COMBINATIONAL_CTPRS_INIT
       ctprs_init[i][j] <= #DELAY `FALSE;
`endif//COMBINATIONAL_CTPRS_INIT
      end//for(N_CTPRS)

      inter_fsp_row_fifo_wren[i] <= #DELAY `FALSE;
    end//for(FSP_HEIGHT)
    
    // And override defaults below
    if(RESET) begin
      zmw_ram_en <= #DELAY `FALSE;
      zmw_ram_read <= #DELAY `FALSE;
      zmw_ram_addr <= #DELAY 0;
      zmw_ram_n_read <= #DELAY 0;
      zmw_ram_state <= #DELAY ZMW_RAM_MSG_WAIT;
      
      ptracer_state <= #DELAY PTRACER_INITIALIZING;
      
      //TODO: initialize from Xillybus
      pixel_bg <= #DELAY 24'h3dfcb;//0.1234 in 24 bits

      ctp_can_accept_row <= #DELAY 0;
      ctp_can_accept_col <= #DELAY 0 - FSP_WIDTH;    
      ctp_state <= #DELAY CTP_INTERFRAME;
    end else begin
      if(zmw_from_ram_fifo_overflow) begin//assertion
        zmw_ram_read <= #DELAY `FALSE;
        zmw_ram_state <= #DELAY ZMW_RAM_ERROR;
      end else begin
        case(zmw_ram_state)
          ZMW_RAM_MSG_WAIT:
            if(zmw_msg_valid) begin
              zmw_ram_en <= #DELAY `TRUE;
              zmw_ram_state <= #DELAY ZMW_RAM_WR_WAIT;
            end else if(!kt_fifo_empty && kinetic_trace_xof) begin
              //The BRAM initialization had better be over by this time!
              zmw_ram_en <= #DELAY `TRUE;
              zmw_ram_addr <= #DELAY 0;
              zmw_ram_read <= #DELAY `TRUE;
              zmw_ram_state <= #DELAY ZMW_RAM_READING;
            end
          ZMW_RAM_WR_WAIT: //wait for the HW to grant write
            if(zmw_ram_rdy && zmw_ram_wdf_rdy) begin
              zmw_ram_wdf_data <= #DELAY whole_pc_msg[0+:RAM_DATA_SIZE];
              // Write at the current zmw_ram_addr
              zmw_ram_wdf_wren <= #DELAY `TRUE;
              zmw_ram_state <= #DELAY ZMW_RAM_WR1;
            end
          ZMW_RAM_WR1://HW writing the 1st of the pair in this state
            if(zmw_ram_wdf_rdy) begin//always TRUE for BRAM
              zmw_ram_wdf_data <= #DELAY whole_pc_msg[RAM_DATA_SIZE+:RAM_DATA_SIZE];
              zmw_ram_wdf_wren <= #DELAY `TRUE;//write the 2nd data
              zmw_ram_addr <= #DELAY zmw_ram_addr + RAM_ADDR_INCR;//Move pointer
              zmw_ram_wdf_end <= #DELAY `TRUE;
              zmw_ram_state <= #DELAY ZMW_RAM_WR2;
            end
          ZMW_RAM_WR2:
            if(zmw_ram_wdf_rdy) zmw_ram_state <= #DELAY ZMW_RAM_MSG_WAIT;
            else zmw_ram_state <= #DELAY ZMW_RAM_ERROR;//assertion
          ZMW_RAM_READING:
            if(zmw_msg_valid) begin//stop read and jump over to SAVING
              zmw_ram_read <= #DELAY `FALSE;//start write
              zmw_ram_addr <= #DELAY 0;//at the head of the DRAM
              zmw_ram_en <= #DELAY `TRUE;
              zmw_ram_state <= #DELAY ZMW_RAM_WR_WAIT;
            end else begin
              if(zmw_ram_rd_data_valid) begin
                //This is unnecessary for N_ZMW power of 2 (because it will
                //wrap around) but emphasizes the intention that we don't want
                //to require N_ZMW to power of 2 ultimately
                zmw_ram_n_read <= #DELAY zmw_ram_n_read == (N_ZMW-1)
                  ? 0 : zmw_ram_n_read + `TRUE;
                //switcheroo of the metadata, to encode the ZMW num
                zmw_from_ram_fifo_din[0+:ZMW_RAM_META_SIZE]
                  <= #DELAY {{(ZMW_RAM_META_SIZE-log2(N_ZMW)){`FALSE}}
						         , zmw_ram_n_read};
                zmw_from_ram_fifo_wren <= #DELAY `TRUE;
              end
              if(zmw_from_ram_fifo_high) begin
                zmw_ram_en <= #DELAY `FALSE;
                zmw_ram_state <= #DELAY ZMW_RAM_THROTTLED;
              end else if(zmw_ram_rdy)//can request the next addr
                zmw_ram_addr <= #DELAY zmw_ram_addr == (N_ZMW-1) //xADDR_INCR
                  ? 0 : zmw_ram_addr + RAM_ADDR_INCR;//Move pointer
            end
          ZMW_RAM_THROTTLED:
            if(zmw_msg_valid) begin//stop read and jump over to SAVING
              zmw_ram_read <= #DELAY `FALSE;
              zmw_ram_addr <= #DELAY 0;
              zmw_ram_en <= #DELAY `TRUE;
              zmw_ram_state <= #DELAY ZMW_RAM_WR_WAIT;
            end else begin
              if(zmw_ram_rd_data_valid) begin
                zmw_ram_n_read <= #DELAY zmw_ram_n_read == (N_ZMW-1)
                  ? 0 : zmw_ram_n_read + `TRUE;
                //switcheroo of the metadata, to encode the ZMW num
                zmw_from_ram_fifo_din[0+:ZMW_RAM_META_SIZE]
                  <= #DELAY {{(ZMW_RAM_META_SIZE-log2(N_ZMW)){`FALSE}}
						         , zmw_ram_n_read};
                zmw_from_ram_fifo_wren <= #DELAY `TRUE;
              end
              if(!zmw_from_ram_fifo_high) begin
				    //Get next data
                zmw_ram_addr <= #DELAY zmw_ram_addr == (N_ZMW-1) //xADDR_INCR
                  ? 0 : zmw_ram_addr + RAM_ADDR_INCR;//Move pointer
                zmw_ram_en <= #DELAY `TRUE;//resume READING
                zmw_ram_state <= #DELAY ZMW_RAM_READING;
              end
            end
          default: begin // What shall we do in ERROR?
          end
        endcase//zmw_ram_state
        
        // Photonic trace code /////////////////////////////////////
        case(ptracer_state)
          PTRACER_INITIALIZING: //TODO: initialize the PSF pool
            if(zmw_ram_state == ZMW_RAM_READING)
              // TODO: correct action
              ptracer_state <= #DELAY PTRACER_RUNNING;
          PTRACER_RUNNING: begin
            if(zmw_from_ram_fifo_valid)
				      inv_dye_mx_addr <= #DELAY zmw_from_ram_spectral_mx_idx;
            
            if(!(zmw_from_ram_fifo_empty || kt_fifo_empty || kinetic_trace_xof)
				      // Just compare what you can
               && zmw_from_ram_fifo_meta != kinetic_trace_zmw[0+:ZMW_RAM_META_SIZE])
            begin
              // TODO: appropriate action on error
              ptracer_state <= #DELAY PTRACER_ERROR;
            end else if(!(zmw_ram_state == ZMW_RAM_READING
                          || zmw_ram_state == ZMW_RAM_THROTTLED)) begin
              // TODO: appropriate action on error
              ptracer_state <= #DELAY PTRACER_INITIALIZING;
            end
          end
          
          default: begin//ERROR
          end
        endcase//ptracer_state

      end//!assertion (i.e. things are fine)

      // Camera trace projector code /////////////////////////////////////
      case(ctp_state)
        CTP_INTERFRAME:
          if(ctrace_xof_d) begin//SOF
            //want to init all CTPRS instances, but can only do 1 col per clock
            for(i=0; i<FSP_HEIGHT; i=i+1) begin
              ctprs_row[i] <= #DELAY i;
              ctprs_col[i] <= #DELAY 0;
              ctprs_to_init[i] <= #DELAY 1;
`ifndef COMBINATIONAL_CTPRS_INIT
              ctprs_init[i][0] <= #DELAY `TRUE;//Left-most pixel
`endif//COMBINATIONAL_CTPRS_INIT
              ctprs_to_ack[i] <= #DELAY 0;
            end//for(FSP_HEIGHT)
            ctp_can_accept_row <= #DELAY 0;
            ctp_can_accept_col <= #DELAY 0 - FSP_WIDTH;
            ctp_state <= #DELAY CTP_INTRAFRAME;
          end//ctrace_xof_d
          
        CTP_INTRAFRAME:
          if(ctp_can_accept_row == (N_ROW - FSP_HEIGHT)
             && ctp_can_accept_col == (N_COL - FSP_WIDTH)) begin
            //At the last pixel => do NOT need a new instance
          end else begin//NOT at the very last pixel => need a new instance
            for(i=0; i<FSP_HEIGHT; i=i+1) begin                  
`ifndef COMBINATIONAL_CTPRS_INIT
              for(j=0; j<N_CTPRS; j=j+1)
                ctprs_init[i][j] <= #DELAY
                  !(ctp_can_accept_row == N_ROW - FSP_HEIGHT//At the last pixel
                    && ctp_can_accept_col == N_COL - FSP_WIDTH)
                  && ctprs_to_init[i] == j//This CTPRS is the one CTP wants
                  && ctprs_avail[i][j];   //and it is available
`endif//COMBINATIONAL_CTPRS_INIT

              if(ctprs_avail[i][ctprs_to_init[i]]) begin//Grabbing this CTPRS
                ctprs_to_init[i] <= #DELAY ctprs_to_init[i] + `TRUE;
                if(ctprs_col[i] == N_COL-1) begin//wrapping
                  ctprs_row[i] <= #DELAY ctprs_row[i] + `TRUE;
                  ctprs_col[i] <= #DELAY 0;
                end else
                  ctprs_col[i] <= #DELAY ctprs_col[i] + `TRUE;

                //sentinel ("can accept") pixel is on the FSP_ROW = 0
                if(i == 0)//Sentinel pixels should move too
                  if(ctp_can_accept_col == N_COL-FSP_WIDTH) begin//wrapping
                    ctp_can_accept_row <= #DELAY ctp_can_accept_row + `TRUE;
                    ctp_can_accept_col <= #DELAY 1 - FSP_WIDTH;
                  end else
                    ctp_can_accept_col <= #DELAY ctp_can_accept_col + `TRUE;
              end//Grabbing this CTPRS
              
              if(ctprs_done[i][ctprs_to_ack[i]]) begin//Copy this CTPRS result
                inter_fsp_row_fifo_din[i] <= #DELAY ctprs_result[i][ctprs_to_ack[i]];
                inter_fsp_row_fifo_wren[i] <= #DELAY `TRUE;
                ctprs_to_ack[i] <= #DELAY ctprs_to_ack[i] + `TRUE;
              end//Copy this CTPRS result

            end//for(FSP_HEIGHT)
          end
          
        default: begin
        end
      endcase//ctp_state
    end//!RESET
  end//always @(posedge CLK)


  //post CTRPS pixel processing code /////////////////////////////////////////
  localparam PIXEL_RAM_ERROR = 0
           , PIXEL_RAM_MSG_WAIT = 1, PIXEL_RAM_WR_WAIT = 2, PIXEL_RAM_WR1 = 3
           , PIXEL_RAM_WR2 = 4, PIXEL_RAM_READING = 5, PIXEL_RAM_THROTTLED = 6
           , PIXEL_RAM_N_STATE = 7;
  reg [log2(PIXEL_RAM_N_STATE)-1:0] pixel_ram_state;
  reg pixel_msg_valid;

  always @(posedge CLK) begin
    if(RESET) begin
    end else begin
    end
  end//always @(posedge CLK)
  

  /////////////////////////////////////////////////////////////////////////////
  //PC message assembler code comes last because it is aware of the FIFO and
  //RAM manager states for the logically separate modules.
  //Message kinds
  localparam PC_MSG_PPROJECTOR = 'b00, PC_MSG_ZMW = 'b01, PC_MSG_PIXEL = 'b10;
  //Message assembler states
  localparam MSG_ASSEMBLER_WAIT1 = 0, MSG_ASSEMBLER_PPROJECTOR = 1
           , MSG_ASSEMBLER_ZMW = 2, MSG_ASSEMBLER_PIXEL = 3
           , MSG_ASSEMBLER_N_STATE = 4;
  reg [log2(MSG_ASSEMBLER_N_STATE)-1:0] msg_assembler_state;
  reg [2*RAM_DATA_SIZE-XB_SIZE-1:0] msg_assembler_cache;
  reg [(2*RAM_DATA_SIZE/XB_SIZE)-1:0] msg_assembler_n;
  always @(posedge CLK) begin
    pprojector_msg_valid <= #DELAY `FALSE;
    zmw_msg_valid <= #DELAY `FALSE;
    pixel_msg_valid <= #DELAY `FALSE;

    if(RESET) msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT1;
    else
      case(msg_assembler_state)
        MSG_ASSEMBLER_WAIT1:
          if(pc_msg_valid) begin
            msg_assembler_cache[0+:XB_SIZE] <= #DELAY pc_msg;
            msg_assembler_n <= #DELAY 1;
            case(pc_msg[2:1])
              PC_MSG_PPROJECTOR:
                msg_assembler_state <= #DELAY MSG_ASSEMBLER_PPROJECTOR;
              PC_MSG_ZMW: msg_assembler_state <= #DELAY MSG_ASSEMBLER_ZMW;
              default: msg_assembler_state <= #DELAY MSG_ASSEMBLER_PIXEL;
            endcase
          end
        MSG_ASSEMBLER_PPROJECTOR:
          if(pc_msg_valid) begin
            if(msg_assembler_n < 2) begin
              msg_assembler_cache[msg_assembler_n*XB_SIZE+:XB_SIZE]
                <= #DELAY pc_msg;
              msg_assembler_n <= #DELAY msg_assembler_n + `TRUE;
            end else if(!assembler2updater_fifo_full) begin
              whole_pc_msg
                <= #DELAY {pc_msg, msg_assembler_cache[0+:2*XB_SIZE]};
              pprojector_msg_valid <= #DELAY `TRUE;
              msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT1;
            end
          end
        MSG_ASSEMBLER_ZMW:
          if(pc_msg_valid) begin
            if(msg_assembler_n < 15) begin
              msg_assembler_cache[msg_assembler_n*XB_SIZE+:XB_SIZE]
                <= #DELAY pc_msg;
              msg_assembler_n <= #DELAY msg_assembler_n + `TRUE;
            end else if(zmw_ram_state == ZMW_RAM_MSG_WAIT) begin
              whole_pc_msg
                <= #DELAY {pc_msg, msg_assembler_cache[0+:15*XB_SIZE]};
              zmw_msg_valid <= #DELAY `TRUE;
              msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT1;
            end
          end
        MSG_ASSEMBLER_PIXEL:
          if(pc_msg_valid) begin
            if(msg_assembler_n < 15) begin
              msg_assembler_cache[msg_assembler_n*XB_SIZE+:XB_SIZE]
                <= #DELAY pc_msg;
              msg_assembler_n <= #DELAY msg_assembler_n + `TRUE;
            end else if(pixel_ram_state == PIXEL_RAM_MSG_WAIT) begin
              whole_pc_msg
                <= #DELAY {pc_msg, msg_assembler_cache[0+:15*XB_SIZE]};
              pixel_msg_valid <= #DELAY `TRUE;
              msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT1;
            end
          end
        default: begin
        end
      endcase//msg_assembler_state
  end//always @(posedge CLK)

  assign #DELAY pc_msg_ack = pc_msg_valid
    && (msg_assembler_state == MSG_ASSEMBLER_WAIT1
        || (msg_assembler_state == MSG_ASSEMBLER_PPROJECTOR
            && (msg_assembler_n < 2 || !assembler2updater_fifo_full))
        || (msg_assembler_state == MSG_ASSEMBLER_ZMW
            && (msg_assembler_n < 15 || zmw_ram_state == ZMW_RAM_MSG_WAIT))
        || (msg_assembler_state == MSG_ASSEMBLER_PIXEL
            && (msg_assembler_n < 15 || pixel_ram_state == PIXEL_RAM_MSG_WAIT)));
endmodule
