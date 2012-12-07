module application#(parameter DELAY=1)
( input CLK, RESET, output[7:0] GPIO_LED);
`include "function.v"
  reg [31:0] tausworth_combined_rand, tausworth_rand[2:0]
    , tausworth_seed[2:0], tausworth_seed_d[2:0]//, tausworth_seed_s[2:0]
    , tausworth_temp_ls[2:0], tausworth_temp_rs[2:0];

  wire[31:0] tausworth_seed_s[2:0]
    , tausworth_temp_l[2:0], tausworth_temp_r[2:0];
  
  integer i;
  genvar geni;
  
  localparam TAUSWORTH_Q0 = 13, TAUSWORTH_D0 = 32'hDEADBEE0
    , TAUSWORTH_SEED0 = ((TAUSWORTH_D0 ^ (TAUSWORTH_D0 << TAUSWORTH_Q0)) >> 31)
                      ^ TAUSWORTH_D0
    , TAUSWORTH_Q1 = 2, TAUSWORTH_D1 = 32'hCAFEBAB0
    , TAUSWORTH_SEED1 = ((TAUSWORTH_D1 ^ (TAUSWORTH_D1 << TAUSWORTH_Q1)) >> 29)
                      ^ TAUSWORTH_D1
    , TAUSWORTH_Q2 = 3, TAUSWORTH_D2 = 32'hACDC0000
    , TAUSWORTH_SEED2 = ((TAUSWORTH_D2 ^ (TAUSWORTH_D2 << TAUSWORTH_Q2)) >> 28)
                      ^ TAUSWORTH_D2;
  localparam TAUSWORTH_INVALID = 0, TAUSWORTH_VALID = 1, TAUSWORTH_N_STATE = 2;
  reg [log2(TAUSWORTH_N_STATE)-1:0] tausworth_state;
  
  localparam TAUSWORTH_DELAY = 4;
  reg [log2(TAUSWORTH_DELAY)-1:0] tausworth_ctr;

`ifndef SEQUENTIAL_LOGIC
  assign tausworth_seed_s[0] = tausworth_seed[0] << TAUSWORTH_Q0;
  assign tausworth_seed_s[1] = tausworth_seed[1] << TAUSWORTH_Q1;
  assign tausworth_seed_s[2] = tausworth_seed[2] << TAUSWORTH_Q2;
      for(i=0; i < 3; i=i+1) tausworth_temp_l[i] <= #DELAY
        tausworth_seed_s[i] ^ tausworth_seed_d[i];
`endif

  always @(posedge CLK)
    if(RESET) begin
      // Initialize the seed
      tausworth_seed[0] <= #DELAY TAUSWORTH_SEED0;
      tausworth_seed[1] <= #DELAY TAUSWORTH_SEED1;
      tausworth_seed[2] <= #DELAY TAUSWORTH_SEED2;
      tausworth_state <= #DELAY TAUSWORTH_INVALID;
      tausworth_ctr <= #DELAY 0;
    end else begin
      tausworth_ctr <= #DELAY tausworth_ctr + `TRUE;
      
      // Result will be valid next cycle
      if(tausworth_state == TAUSWORTH_INVALID
         && tausworth_ctr == TAUSWORTH_DELAY)
         tausworth_state <= #DELAY TAUSWORTH_VALID;
      
      // Delay 1
      for(i=0; i < 3; i=i+1) tausworth_seed_d[i] <= #DELAY tausworth_seed[i];

`ifdef SEQUENTIAL_LOGIC
      tausworth_seed_s[0] <= #DELAY tausworth_seed[0] << TAUSWORTH_Q0;
      tausworth_seed_s[1] <= #DELAY tausworth_seed[1] << TAUSWORTH_Q1;
      tausworth_seed_s[2] <= #DELAY tausworth_seed[2] << TAUSWORTH_Q2;

      // Delay 2
      for(i=0; i < 3; i=i+1) tausworth_temp_l[i] <= #DELAY
        tausworth_seed_s[i] ^ tausworth_seed_d[i];
        
      tausworth_temp_r[0] <= #DELAY tausworth_seed_d[0] & 32'hFFFFFFFE;//k=31
      tausworth_temp_r[1] <= #DELAY tausworth_seed_d[1] & 32'hFFFFFFF8;//k=29
      tausworth_temp_r[2] <= #DELAY tausworth_seed_d[2] & 32'hFFFFFFF0;//k=28

      // Delay 3
      tausworth_temp_ls[0] <= #DELAY tausworth_temp_l[0] << 19;
      tausworth_temp_rs[0] <= #DELAY tausworth_temp_r[0] << 12;
        
      tausworth_temp_ls[1] <= #DELAY tausworth_temp_l[1] << 25;
      tausworth_temp_rs[1] <= #DELAY tausworth_temp_r[1] << 4;

      tausworth_temp_ls[2] <= #DELAY tausworth_temp_l[2] << 11;
      tausworth_temp_rs[2] <= #DELAY tausworth_temp_r[2] << 17;
      
      // Delay 4
      for(i=0; i < 3; i=i+1) tausworth_rand[i] <= #DELAY
        tausworth_temp_ls[i] ^ tausworth_temp_rs[i];
      // Delay 5
`endif
      tausworth_combined_rand <= #DELAY
        tausworth_rand[0] ^ tausworth_rand[1] ^ tausworth_rand[2];
    end
endmodule
