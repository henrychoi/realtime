module application#(parameter DELAY=1)
( input CLK, RESET, output[7:0] GPIO_LED);
`include "function.v"
  reg [31:0] tausworth_combined_rand, tausworth_seed[2:0];
  wire[31:0] tausworth_seed_s[2:0]
    , tausworth_temp_l[2:0], tausworth_temp_r[2:0]
    , tausworth_temp_ls[2:0], tausworth_temp_rs[2:0]
    , tausworth_rand[2:0];
  
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

  assign #DELAY GPIO_LED = tausworth_combined_rand[7:0];
  
  assign #DELAY tausworth_seed_s[0] = tausworth_seed[0] << TAUSWORTH_Q0;
  assign #DELAY tausworth_seed_s[1] = tausworth_seed[1] << TAUSWORTH_Q1;
  assign #DELAY tausworth_seed_s[2] = tausworth_seed[2] << TAUSWORTH_Q2;

  for(geni=0; geni < 3; geni=geni+1)
    assign #DELAY tausworth_temp_l[geni] =
      tausworth_seed_s[geni] ^ tausworth_seed[geni];

  assign #DELAY tausworth_temp_r[0] = tausworth_seed[0] & 32'hFFFFFFFE;//k=31
  assign #DELAY tausworth_temp_r[1] = tausworth_seed[1] & 32'hFFFFFFF8;//k=29
  assign #DELAY tausworth_temp_r[2] = tausworth_seed[2] & 32'hFFFFFFF0;//k=28

  assign #DELAY tausworth_temp_ls[0] = tausworth_temp_l[0] >> 19;
  assign #DELAY tausworth_temp_rs[0] = tausworth_temp_r[0] << 12;
  assign #DELAY tausworth_temp_ls[1] = tausworth_temp_l[1] >> 25;
  assign #DELAY tausworth_temp_rs[1] = tausworth_temp_r[1] << 4;
  assign #DELAY tausworth_temp_ls[2] = tausworth_temp_l[2] >> 11;
  assign #DELAY tausworth_temp_rs[2] = tausworth_temp_r[2] << 17;

  for(geni=0; geni < 3; geni=geni+1)
    assign #DELAY tausworth_rand[geni] =
      tausworth_temp_ls[geni] ^ tausworth_temp_rs[geni];

  always @(posedge CLK)
    if(RESET) begin
      // Initialize the seed
      tausworth_seed[0] <= TAUSWORTH_SEED0;
      tausworth_seed[1] <= TAUSWORTH_SEED1;
      tausworth_seed[2] <= TAUSWORTH_SEED2;
      tausworth_state <= TAUSWORTH_INVALID;
      tausworth_ctr <= 0;
    end else begin
      tausworth_ctr <= tausworth_ctr + `TRUE;
      
      // Result will be valid next cycle
      if(tausworth_state == TAUSWORTH_INVALID
         && tausworth_ctr == TAUSWORTH_DELAY)
         tausworth_state <= TAUSWORTH_VALID;
      
      for(i=0; i < 3; i=i+1) tausworth_seed[i] <= #DELAY tausworth_rand[i];

      tausworth_combined_rand <= #DELAY
        tausworth_rand[0] ^ tausworth_rand[1] ^ tausworth_rand[2];
    end
endmodule
