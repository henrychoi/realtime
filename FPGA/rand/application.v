module application#(parameter DELAY=1)
( input CLK, RESET, output[7:0] GPIO_LED);
`include "function.v"
  integer i;
  genvar geni;
  
  localparam N_GENERATOR = 3;
  localparam ERROR = 0, INITIAL1 = 1, INITIAL2 = 2, VALID = 3, N_STATE = 4;
  reg [log2(N_STATE)-1:0] state;
  
  reg [31:0] frand, combined_rand, seed[N_GENERATOR-1:0];
  wire[31:0] seed_s[N_GENERATOR-1:0]
    , temp_l[N_GENERATOR-1:0], temp_r[N_GENERATOR-1:0]
    , temp_ls[N_GENERATOR-1:0], temp_rs[N_GENERATOR-1:0]
    , rand[N_GENERATOR-1:0];

  localparam Q0 = 13,D0 = 32'hDEADBEE0, SEED0 = ((D0 ^ (D0 << Q0)) >> 31)^D0
           , Q1 = 2, D1 = 32'hCAFEBAB0, SEED1 = ((D1 ^ (D1 << Q1)) >> 29)^D1
           , Q2 = 3, D2 = 32'hACDC0000, SEED2 = ((D2 ^ (D2 << Q2)) >> 28)^D2;

  assign #DELAY GPIO_LED[0+:log2(N_STATE)] = state;
  assign #DELAY GPIO_LED[7:log2(N_STATE)] = frand[7:log2(N_STATE)];
  
  assign #DELAY seed_s[0] = seed[0] << Q0;
  assign #DELAY seed_s[1] = seed[1] << Q1;
  assign #DELAY seed_s[2] = seed[2] << Q2;

  for(geni=0; geni < N_GENERATOR; geni=geni+1)
    assign #DELAY temp_l[geni] = seed_s[geni] ^ seed[geni];

  assign #DELAY temp_r[0] = seed[0] & 32'hFFFFFFFE;//k=31
  assign #DELAY temp_r[1] = seed[1] & 32'hFFFFFFF8;//k=29
  assign #DELAY temp_r[2] = seed[2] & 32'hFFFFFFF0;//k=28

  assign #DELAY temp_ls[0] = temp_l[0] >> 19;
  assign #DELAY temp_rs[0] = temp_r[0] << 12;
  assign #DELAY temp_ls[1] = temp_l[1] >> 25;
  assign #DELAY temp_rs[1] = temp_r[1] << 4;
  assign #DELAY temp_ls[2] = temp_l[2] >> 11;
  assign #DELAY temp_rs[2] = temp_r[2] << 17;

  for(geni=0; geni < N_GENERATOR; geni=geni+1)
    assign #DELAY rand[geni] = temp_ls[geni] ^ temp_rs[geni];

  always @(posedge CLK)
    if(RESET) begin
      // Initialize the seed
      seed[0] <= SEED0;
      seed[1] <= SEED1;
      seed[2] <= SEED2;
      combined_rand <= #DELAY rand[0] ^ rand[1] ^ rand[2];
      state <= INITIAL1;
    end else begin
      combined_rand <= #DELAY rand[0] ^ rand[1] ^ rand[2];
      frand <= #DELAY {`FALSE//sign
                      , `FALSE, combined_rand[24+:6], `FALSE //exponent
                      , combined_rand[0+:23]};//fraction
      for(i=0; i < N_GENERATOR; i=i+1) seed[i] <= #DELAY rand[i];
      case(state)
        INITIAL1: state <= #DELAY INITIAL2;
        INITIAL2: state <= #DELAY VALID;
        VALID: //new number the same as old?
          for(i=0; i < N_GENERATOR; i=i+1)
            if(rand[i] == seed[i]) state <= #DELAY ERROR;
        default: begin //If error state, stay there!
        end
      endcase
    end
endmodule
