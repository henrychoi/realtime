module application#(parameter DELAY=1, XB_SIZE=32, RAM_DATA_SIZE=1)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output pc_msg_ack
, output reg fpga_msg_valid, output reg [XB_SIZE-1:0] fpga_msg
, output app_running, app_error);
`include "function.v"
  localparam RAM_HEADER_SIZE = 8, ZMW_DATA_SIZE = RAM_DATA_SIZE - RAM_HEADER_SIZE
           , FP_SIZE = 30
           , MAX_STRIDE = 2**8 - 1, MAX_CLOCK_PER_FRAME = 2**24 - 1
           , MAX_FRAME = 2**24 - 1;
  reg [log2(MAX_STRIDE)-1:0] max_stride, n_stride;
  reg [log2(MAX_CLOCK_PER_FRAME)-1:0] clock_per_frame, n_clock;
  reg [log2(MAX_FRAME)-1:0] max_frame, n_frame;
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
  assign to_ram_fifo_valid = {!to_ram_fifo_empty[1], !to_ram_fifo_empty[0]};

  wire from_ram_fifo_ack, from_ram_fifo_empty, from_ram_fifo_valid
     , from_ram_fifo_high, from_ram_fifo_full, from_ram_fifo_almost_full;
  wire[RAM_HEADER_SIZE-1:0] from_ram_fifo_header;
  wire[ZMW_DATA_SIZE-1:0]   from_ram_fifo_data;
  // register the inputs for timing margin
  reg  from_ram_src, from_ram_fifo_wren;
  reg [RAM_DATA_SIZE-1:0] from_ram_fifo_din;
  
  better_fifo#(.TYPE("FromRAM"), .WIDTH(RAM_DATA_SIZE), .DELAY(DELAY))
  from_ram_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
              , .wren(from_ram_fifo_wren), .din(from_ram_fifo_din)
              , .high(from_ram_fifo_high), .full(from_ram_fifo_full)
              , .almost_full(from_ram_fifo_almost_full)
              , .rden(from_ram_fifo_ack)
              , .dout({from_ram_fifo_data, from_ram_fifo_header})
              , .empty(from_ram_fifo_empty), .almost_empty());
  assign from_ram_fifo_valid = !from_ram_fifo_empty;
  assign from_ram_fifo_ack = from_ram_fifo_valid && !to_ram_fifo_full;
  
  integer i;
  genvar geni;
  generate
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
          (ram_state[geni] == RAM_WR1 && to_ram_fifo_dout[geni][0] && //is data
           !ram_wdf_rdy[geni]));
`endif

      PulseListBRAM
      list(.clka(CLK), .douta(ram_rd_data[geni])
         , .addra(ram_addr[geni]), .dina(ram_wdf_data)
         , .wea(ram_wdf_wren[geni]));             
    end
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
           , CONTROL_MSG_EXPOSURE_SIZE = 32;
  wire is_control_msg, is_start_msg, is_stop_msg;
  assign #DELAY is_control_msg = whole_pc_msg_valid
                              && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE;
  assign #DELAY is_start_msg = whole_pc_msg_valid
             && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE//control msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `TRUE;//start msg
  assign #DELAY is_stop_msg = whole_pc_msg_valid
             && whole_pc_msg[MSG_HEADER_TYPE_BIT] == `FALSE//control msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE;//stop msg

  assign #DELAY pc_msg_ack = pc_msg_valid;
  
  always @(posedge CLK) begin
    if(RESET) begin
      fpga_msg_valid <= #DELAY `FALSE;
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
      from_ram_fifo_wren <= #DELAY `FALSE;
    end else begin
      ram_en_and_read[0] <= #DELAY ram_en & ram_read;//bitwise
      for(i=1; i<BRAM_READ_LATENCY-1; i=i+1)
        ram_en_and_read[i] <= #DELAY ram_en_and_read[i-1];
      ram_rd_data_valid <= #DELAY ram_en_and_read[BRAM_READ_LATENCY-2];

      from_ram_fifo_wren <= #DELAY ram_rd_data_valid[from_ram_src];
      from_ram_fifo_din <= #DELAY ram_rd_data[from_ram_src];
  
      fpga_msg_valid <= #DELAY `FALSE;

      //Message assembler code
      whole_pc_msg_valid <= #DELAY `FALSE;
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
    
      //Pacer code
      for(i=0; i<2; i=i+1) to_ram_fifo_wren[i] <= #DELAY `FALSE;
      case(pacer_state)
        PACER_STOPPED:
          if(is_start_msg) begin
            max_frame <= #DELAY whole_pc_msg[CONTROL_MSG_N_FRAME_BIT
                                           +:CONTROL_MSG_N_FRAME_SIZE];
            clock_per_frame <= #DELAY whole_pc_msg[
               CONTROL_MSG_N_CLOCK_PER_FRAME_BIT +:CONTROL_MSG_N_CLOCK_PER_FRAME_SIZE];
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
          if(from_ram_fifo_valid) begin
            // check the answer
            if(!from_ram_fifo_header[0] // RAM should not hold metadata
               || from_ram_fifo_data[0+:log2(N_ZMW)] != rd_zmw)
            begin
              // ^STOP to both RAM controllers
              for(i=0; i<2; i=i+1) begin
                to_ram_fifo_header[i] <= #DELAY 'h00;
                to_ram_fifo_wren[i] <= #DELAY `TRUE;
              end
              pacer_state <= #DELAY PACER_ERROR;
            end else begin // write to ~src RAM
              to_ram_fifo_header[~from_ram_src] <= #DELAY 'h01; // is data
              to_ram_fifo_wren[~from_ram_src] <= #DELAY `TRUE;
              //To do: update the pulse definition when a new one comes in
              to_ram_fifo_data <= #DELAY from_ram_fifo_data;
              
              rd_zmw <= #DELAY rd_zmw + `TRUE;
              if(rd_zmw == N_ZMW-1) begin // done checking
                // ^STOP to RAM[src]
                to_ram_fifo_header[from_ram_src] <= #DELAY 'b0000_0000;
                to_ram_fifo_wren[from_ram_src] <= #DELAY `TRUE;
                pacer_state <= #DELAY PACER_STOPPING_FRAME;
              end else begin//if(rd_zmw == N_ZMW-1)
                pacer_state <= #DELAY to_ram_fifo_full[~from_ram_src]
                             ? PACER_FRAME_THROTTLED : PACER_FRAME;
              end
            end//else
          end//!to_ram_fifo_high
        end//if(from_ram_fifo_valid)
          
        PACER_FRAME_THROTTLED: begin
          n_clock <= #DELAY n_clock + `TRUE;
          pacer_state <= #DELAY to_ram_fifo_full[~from_ram_src]
                       ? PACER_FRAME_THROTTLED : PACER_FRAME;
        end

        PACER_STOPPING_FRAME: begin
          n_clock <= #DELAY n_clock + `TRUE;
          //^EOF
          if(n_frame == max_frame) pacer_state <= #DELAY PACER_STOPPING;
          else if(!to_ram_fifo_full[~from_ram_src]) begin
            //^STOP to RAM[~src]
            to_ram_fifo_header[~from_ram_src] <= #DELAY 'b0000_0000;
            to_ram_fifo_wren[~from_ram_src] <= #DELAY `TRUE;
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
              end else begin //record state transition
                fpga_msg <= #DELAY {to_ram_fifo_dout[i][0+:8], ram_state[i]
                                  , 'h0000};
                fpga_msg_valid <= #DELAY `TRUE;
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
          
        endcase
      end
    end
  end
endmodule
