#ifndef control_trajectory
#define control_trajectory

#include "qep_port.h" //Defines the types

typedef void (*Trajectory1_nextMethod)(struct Trajectory1* me);
typedef struct {
  float pos, vel, acc// What a scalar trajectory emits
    , period, s;
  Trajectory1_nextMethod next;
} Trajectory1;

typedef struct {
  Trajectory1 super;
  uint32_t k;
  float p[4], v[4], a[4];// at the BEGINNING of each phase
  float vi, v0, tf[4];
} BangBang1;
uint8_t BangBang1_initialize(BangBang1* me);
uint8_t BangBang1_reset(BangBang1* me
  , float period, float convergence
    , float pinitial, float pfinal
    , float vinitial, float smax
    , float amax, float dmax);

typedef struct {
  Trajectory1 super;
  size_t k;
  float tf[10];
} Trapezoidal1;
uint8_t Trapezoidal1_initialize(Trapezoidal1* me);
uint8_t Trapezoidal1_reset(Trapezoidal1* me
  , float period
    , float pinitial, float pfinal
    , float vinitial, float smax
    , float amax, float dmax
    , float jerk);

#endif//control_trajectory