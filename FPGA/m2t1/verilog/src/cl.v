module clsim(input reset
, output reg cl_fval, cl_z_lval, input cl_z_pclk
, output reg[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j);
  `include "function.v"
  localparam CAMSTATE_NOFRAME=0, CAMSTATE_LVAL=1, CAMSTATE_INTERLINE=2
    , MAX_CAMSTATE = 3;
  reg[1:0] camstate;
  localparam N_CLCLK_SIZE = 10
    , FVAL_LOW_DURATION = 40
    , LVAL_LOW_DURATION = 7
    , N_COL = 20//780
    , N_ROW = 4;//1080;
  reg[N_CLCLK_SIZE-1:0] n_clclk;
  reg[10:0] n_row;
  reg[19:0] n_frame;
  
  always @(posedge reset, posedge cl_z_pclk)
    if(reset) begin
      n_clclk <= 0;
      camstate <= CAMSTATE_NOFRAME;
      n_row <= 0;
      n_frame <= 0;
      cl_fval <= `FALSE; cl_z_lval <= `FALSE;
      cl_port_a <= 8'h0A;
      cl_port_b <= 8'h0B;
      cl_port_c <= 8'h0C;
      cl_port_d <= 8'h0D;
      cl_port_e <= 8'h0E;
      cl_port_f <= 8'h0F;
      cl_port_g <= 8'h09;
      cl_port_h <= 8'h06;
      cl_port_i <= 8'h01;
      cl_port_j <= 8'h07;
    end else begin
      n_clclk <= n_clclk + 1'b1;
      case(camstate)
        CAMSTATE_NOFRAME:
          if(n_clclk == FVAL_LOW_DURATION) begin
            camstate <= CAMSTATE_LVAL;
            n_clclk <= 0;
            n_frame <= n_frame + 1'b1;
            n_row <= 0;
            cl_fval <= `TRUE; cl_z_lval <= `TRUE;
          end
        CAMSTATE_LVAL:
          if(n_clclk == (N_COL-1)) begin
            if(n_row == (N_ROW-1)) begin
              cl_fval <= `FALSE;
              camstate <= CAMSTATE_NOFRAME;
            end else camstate <= CAMSTATE_INTERLINE;
            n_clclk <= 0;
            cl_z_lval <= `FALSE;
          end
        CAMSTATE_INTERLINE:
          if(n_clclk == LVAL_LOW_DURATION) begin
            camstate <= CAMSTATE_LVAL;
            n_clclk <= 0;
            n_row <= n_row + 1'b1;
            cl_z_lval <= `TRUE;
          end
      endcase

      cl_port_a[4] <= ~cl_port_a[4];
      cl_port_b[4] <= ~cl_port_b[4];
      cl_port_c[4] <= ~cl_port_c[4];
      cl_port_d[4] <= ~cl_port_d[4];
      cl_port_e[4] <= ~cl_port_e[4];
      cl_port_f[4] <= ~cl_port_f[4];
      cl_port_g[4] <= ~cl_port_g[4];
      cl_port_h[4] <= ~cl_port_h[4];
      cl_port_i[4] <= ~cl_port_i[4];
      cl_port_j[4] <= ~cl_port_j[4];
    end
endmodule
