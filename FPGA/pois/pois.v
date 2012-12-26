module rand#(parameter DELAY=1)
(input CLK, RESET, output valid, output error, output reg[31:0] rand);
`include "function.v"
  integer i;
  genvar geni;
  
  localparam N_GENERATOR = 3;
  localparam ERROR = 0, INITIAL1 = 1, INITIAL2 = 2, VALID = 3, N_STATE = 4;
  reg [log2(N_STATE)-1:0] state;
  assign #DELAY valid = state == VALID;
  assign #DELAY error = state == ERROR;
  
  reg [31:0] seed[N_GENERATOR-1:0];
  wire[31:0] seed_s[N_GENERATOR-1:0]
    , temp_l[N_GENERATOR-1:0], temp_r[N_GENERATOR-1:0]
    , temp_ls[N_GENERATOR-1:0], temp_rs[N_GENERATOR-1:0]
    , new_rand[N_GENERATOR-1:0];

  localparam Q0 = 13,D0 = 32'hDEADBEE0, SEED0 = ((D0 ^ (D0 << Q0)) >> 31)^D0
           , Q1 = 2, D1 = 32'hCAFEBAB0, SEED1 = ((D1 ^ (D1 << Q1)) >> 29)^D1
           , Q2 = 3, D2 = 32'hACDC0000, SEED2 = ((D2 ^ (D2 << Q2)) >> 28)^D2;

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
    assign #DELAY new_rand[geni] = temp_ls[geni] ^ temp_rs[geni];

  always @(posedge CLK)
    if(RESET) begin
      // Initialize the seed
      seed[0] <= SEED0;
      seed[1] <= SEED1;
      seed[2] <= SEED2;
      rand <= #DELAY new_rand[0] ^ new_rand[1] ^ new_rand[2];
      state <= INITIAL1;
    end else begin
      for(i=0; i < N_GENERATOR; i=i+1) seed[i] <= #DELAY new_rand[i];
      rand <= #DELAY new_rand[0] ^ new_rand[1] ^ new_rand[2];
      case(state)
        INITIAL1: state <= #DELAY INITIAL2;
        INITIAL2: state <= #DELAY VALID;
        VALID: //new number the same as old?
          for(i=0; i < N_GENERATOR; i=i+1)
            if(new_rand[i] == seed[i]) state <= #DELAY ERROR;
        default: begin //If error state, stay there!
        end
      endcase
    end
endmodule
