module application#(parameter DELAY=1, XB_SIZE=32, DRAM_DATA_SIZE=1)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output reg pc_msg_ack
, output reg fpga_msg_valid, output reg [XB_SIZE-1:0] fpga_msg);
`include "function.v"  
  localparam FP_SIZE = 30;
  localparam ERROR = 0, INIT = 1, SRC0 = 2, SRC1 = 3, N_STATE = 4;
  reg [log2(N_STATE)-1:0] state;

  localparam N_ZMW = 128, BRAM_READ_DELAY = 3;
  reg [log2(N_ZMW)-1:0] pulses_addr[1:0]
    , pulses_addr_d[BRAM_READ_DELAY-1:0], zmw_num;
  reg [1:0] pulses_wren;
  wire[DRAM_DATA_SIZE-1:0] pulses_out[1:0];
  reg [DRAM_DATA_SIZE-1:0] pulses_in;
  reg pulses_src;
  
  integer i;
  genvar geni;
  generate
    for(geni=0; geni<2; geni=geni+1)
      PulseListBRAM list(.clka(CLK), .douta(pulses_out[geni])
                       , .addra(pulses_addr[geni]), .dina(pulses_in)
                       , .wea(pulses_wren[geni]));
  endgenerate

  assign #DELAY GPIO_LED = {`FALSE, state};

  always @(posedge CLK) begin
    if(RESET) begin
      state <= #DELAY INIT;
      for(i=0; i<2; i=i+1) pulses_addr[i] <= #DELAY {log2(N_ZMW){`FALSE}};
      pulses_src <= #DELAY 1'b0;
      pulses_in <= #DELAY {DRAM_DATA_SIZE{`FALSE}};
      pulses_wren <= #DELAY {`FALSE, `TRUE};
    end else begin
      pulses_addr_d[0] <= #DELAY pulses_addr[pulses_src];
      for(i=1; i<BRAM_READ_DELAY; i=i+1)
        pulses_addr_d[i] <= #DELAY pulses_addr_d[i-1];
      zmw_num <= #DELAY pulses_addr_d[BRAM_READ_DELAY-1];
      
      case(state)
        INIT: begin
          pulses_addr[pulses_src] <= #DELAY pulses_addr[pulses_src] + `TRUE;
          //pulses_in[224+:log2(N_ZMW)] <= #DELAY pulses_addr[pulses_src];
          if(pulses_addr[pulses_src] == (N_ZMW-1)) begin // reached the end
            pulses_wren[pulses_src] <= #DELAY `FALSE;
          end
          if(zmw_num == (N_ZMW-1)) state <= #DELAY SRC;
        end
        
        CHECK: begin
          pulses_addr[pulses_src] <= #DELAY pulses_addr[pulses_src] + `TRUE;
          if(|pulses_out[pulses_src]) state <= #DELAY ERROR;
          else if(pulses_addr[pulses_src] == (N_ZMW-1)) // reached the end
            state <= #DELAY READY;
        end
        
        READY: begin
        end
        
        default: begin // ERROR
        end
      endcase
    end
  end
endmodule
