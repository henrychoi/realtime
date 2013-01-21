module application#(parameter DELAY=1, XB_SIZE=32, RAM_DATA_SIZE=1)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output pc_msg_ack
, output reg fpga_msg_valid, output reg [XB_SIZE-1:0] fpga_msg
, output app_running, app_error, msg_error);
`include "function.v"  
  localparam FP_SIZE = 30
           , MAX_STRIDE = 2**8 - 1, MAX_CLOCK_PER_FRAME = 2**24 - 1
           , MAX_FRAME = 2**24 - 1;
  reg [log2(MAX_STRIDE)-1:0] max_stride, n_stride;
  reg [log2(MAX_CLOCK_PER_FRAME)-1:0] max_clock_per_frame, n_clock;
  reg [log2(MAX_FRAME)-1:0] max_frame, n_frame;
  reg [FP_SIZE-1:0] exposure;
  
  localparam MSG_ASSEMBLER_ERROR = 0, MSG_ASSEMBLER_WAIT1 = 1
           , MSG_ASSEMBLER_WAIT2 = 2, MSG_ASSEMBLER_WAIT3 = 3
           , MSG_ASSEMBLER_N_STATE = 4;
  reg [log2(MSG_ASSEMBLER_N_STATE)-1:0] msg_assembler_state;
  assign #DELAY msg_error = !msg_assembler_state; 
  reg [2*XB_SIZE-1:0] msg_assembler_cache;
  reg [3*XB_SIZE-1:0] whole_pc_msg;
  reg whole_pc_msg_valid;

  localparam PACER_ERROR = 0, PACER_STOPPED = 1
           , PACER_INIT = 2, PACER_INIT_PAUSED = 3, PACER_POST = 4
           , PACER_INTRAFRAME = 5, PACER_INTERFRAME = 6, PACER_N_STATE = 7;
  reg [log2(PACER_N_STATE)-1:0] pacer_state;
  assign #DELAY app_running = pacer_state == PACER_INTRAFRAME
                           && pacer_state == PACER_INTERFRAME;
  assign #DELAY app_error = !pacer_state; 
  assign #DELAY GPIO_LED = {pacer_state, msg_error};
  
  localparam RAM_ERROR = 0
           , RAM_WR1 = 1, RAM_WR2 = 2, RAM_MSG_WAIT = 3, RAM_WR_WAIT = 4
           , RAM_READING = 5, RAM_THROTTLED = 6, RAM_FINISHING_RD = 7
           , RAM_IDLE = 8, RAM_N_STATE = 9;
  reg [log2(RAM_N_STATE)-1:0] ram_state[1:0];
  
  localparam N_ZMW = 128, BRAM_READ_DELAY = 3;
  reg [log2(N_ZMW)-1:0] ram_addr[1:0], wr_zmw;
  reg [1:0] ram_wren;
  wire[RAM_DATA_SIZE-1:0] ram_out[1:0], to_ram_fifo_dout[1:0];
  reg [RAM_DATA_SIZE-1:0] to_ram_fifo_din, ram_din;
  reg[1:0] to_ram_fifo_wren, to_ram_fifo_ack;
  wire[1:0] to_ram_fifo_full, to_ram_fifo_almost_full
     , to_ram_fifo_empty, to_ram_fifo_valid;
  assign #DELAY to_ram_fifo_valid = {!to_ram_fifo_empty[1]
                                   , !to_ram_fifo_empty[0]};
  
  //localparam PACER2RAM_MSG_NONE = 0, PACER2RAM_MSG_SOF = 1, PACER2RAM_MSG_EOF = 2
  //         , PACER2RAM_N_MSG = 3;
  //reg [log2(PACER2RAM_N_MSG)-1:0] pacer2ram_msg[1:0];
  
  integer i;
  genvar geni;
  generate
    for(geni=0; geni<2; geni=geni+1) begin
      better_fifo#(.TYPE("ToRAM"), .WIDTH(RAM_DATA_SIZE), .DELAY(DELAY))
      to_ram_fifo(.RESET(RESET), .RD_CLK(CLK), .WR_CLK(CLK)
                , .din(to_ram_fifo_din), .wren(to_ram_fifo_wren[geni])
                , .full(to_ram_fifo_full[geni])
                , .almost_full(to_ram_fifo_almost_full[geni])
                , .rden(to_ram_fifo_ack[geni]), .dout(to_ram_fifo_dout[geni])
                , .empty(to_ram_fifo_empty[geni]));

      PulseListBRAM
      list(.clka(CLK), .douta(ram_out[geni])
         , .addra(ram_addr[geni]), .dina(ram_din), .wea(ram_wren[geni]));                       
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
      msg_assembler_state <= #DELAY MSG_ASSEMBLER_WAIT1;
      pacer_state <= #DELAY PACER_STOPPED;
      for(i=0; i<2; i=i+1) begin
        to_ram_fifo_wren[i] <= #DELAY `FALSE;
        ram_wren[i] <= #DELAY `FALSE;
        ram_state[i] <= #DELAY RAM_IDLE;
      end
    end else begin
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
    
      for(i=0; i<2; i=i+1) to_ram_fifo_wren[i] <= #DELAY `FALSE;
      
      case(pacer_state)
        PACER_STOPPED:
          if(is_start_msg) begin
            max_frame <= #DELAY whole_pc_msg[CONTROL_MSG_N_FRAME_BIT
                                           +:CONTROL_MSG_N_FRAME_SIZE];
            max_clock_per_frame <= #DELAY whole_pc_msg[CONTROL_MSG_N_CLOCK_PER_FRAME_BIT
                                            +:CONTROL_MSG_N_CLOCK_PER_FRAME_SIZE];
            max_stride <= #DELAY whole_pc_msg[CONTROL_MSG_STRIDE_BIT
                                            +:CONTROL_MSG_STRIDE_SIZE];
            exposure <= #DELAY whole_pc_msg[(3*XB_SIZE-1)-:FP_SIZE];

            // ^SOF to 1st RAM controller
            to_ram_fifo_din <= #DELAY {RAM_DATA_SIZE{`FALSE}};
            to_ram_fifo_din[1] <= #DELAY `TRUE;//SOF
            to_ram_fifo_din[2] <= #DELAY `TRUE;//Write
            to_ram_fifo_wren[0] <= #DELAY `TRUE;

            pacer_state <= #DELAY PACER_INIT;
          end
        
        PACER_INIT:
          if(is_control_msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE) begin//STOP
            // ^EOF to 1st RAM controllers
            to_ram_fifo_din[0] <= #DELAY {RAM_DATA_SIZE{`FALSE}};
            to_ram_fifo_wren[0] <= #DELAY `TRUE;
            pacer_state <= #DELAY PACER_STOPPED;
          end else if(to_ram_fifo_full[0]) begin
            to_ram_fifo_wren[0] <= #DELAY `FALSE;
            pacer_state <= #DELAY PACER_INIT_PAUSED;
          end else begin
            // Just emitted SOF to 1st RAM?
            if(to_ram_fifo_din[1:0] == 2'b10) begin
              to_ram_fifo_din[0] <= #DELAY `TRUE; //non-control msg from now
              wr_zmw <= #DELAY 0;
            end else wr_zmw <= #DELAY wr_zmw + `TRUE;
            
            to_ram_fifo_wren[0] <= #DELAY `TRUE;

            if(wr_zmw == (N_ZMW-1)) begin
              // ^EOF to 1st RAM controller
              to_ram_fifo_din[1:0] <= #DELAY 'b00;
              pacer_state <= #DELAY PACER_POST;
            end
          end
        
        PACER_INIT_PAUSED:
          if(is_control_msg
             && whole_pc_msg[CONTROL_MSG_START_BIT] == `FALSE) begin//STOP
            // ^EOF to 1st RAM controllers
            to_ram_fifo_din[0] <= #DELAY {RAM_DATA_SIZE{`FALSE}};
            to_ram_fifo_wren[0] <= #DELAY `TRUE;
            pacer_state <= #DELAY PACER_STOPPED;
          end else if(!to_ram_fifo_full[0]) begin
            to_ram_fifo_wren[0] <= #DELAY `TRUE;
            pacer_state <= #DELAY PACER_INIT;
          end
          
        PACER_POST: begin
          if(to_ram_fifo_din[1:0] == 'b00) begin//Just emitted EOF to 1st RAM
            to_ram_fifo_din[2:1] <= #DELAY {`FALSE, `TRUE}; //^SOF(RD)
            to_ram_fifo_wren[0] <= #DELAY `TRUE;
          end
          //If there is an answer, check the answer
        end
        
        PACER_INTERFRAME: begin
        end
        
        PACER_INTRAFRAME: begin
        end

        default: begin // ERROR
        end
      endcase//pacer_state

      for(i=0; i<2; i=i+1) begin
        to_ram_fifo_ack[i] <= #DELAY `FALSE;
        
        case(ram_state[i])
          RAM_IDLE:
            if(to_ram_fifo_valid[i]) begin
              to_ram_fifo_ack[i] <= #DELAY `TRUE;
              
              if(to_ram_fifo_dout[i][0] == `FALSE //sentinel message
                 && to_ram_fifo_dout[i][1] == `TRUE) begin //SOF
                if(to_ram_fifo_dout[i][2] == `TRUE) begin
                  ram_state[i] <= #DELAY RAM_MSG_WAIT;
                end else begin
                  ram_state[i] <= #DELAY RAM_READING;
                end
              end
            end
          
          default: begin
          end
        endcase
      end
    end
  end
endmodule
