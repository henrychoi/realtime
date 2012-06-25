#include <string.h>
#include "platform/functions.h"
#include "control/trajectory.h"

BangBang1* BangBang1_ctor();
uint8_t BangBang1_reset(BangBang1* me
  , float period, float convergence
    , float pi, float pf
    , float vi, float smax
    , float amax, float dmax)
{
  float T[4]; memset(T, 0, sizeof(T));
  me->k = 0;
  me->super.period = period;
  me->vi = vi;

  me->p[0] = pi;// I will always start from current position

  // Firstly, which direction am I going?
  if(pf > pi) me->super.s = 1.f;
  else if(pf < pi) me->super.s = -1.f;
  else {
    if(vi == 0) { // trivial case: no movement
      me->super.s = 0;
      memset(me->a, 0, sizeof(me->a));
      me->p[0] = me->p[1] = me->p[2] = me->p[3] = pi;
      return 1;
    } else {//Need to go the other way from current velocity
		  me->super.s = -fsign(vi);
    }
  }

  // Invariant: sign != 0 at this point
  do { // iterate until all timing constraints are met
    if(vi * me->super.s > 0) {// Is the initial velocity the same sign as s?
      T[0] = 0;
      //p[1] = p[0];
      me->v0 = vi;
    } else {//If not, slow down first
      T[0] = -me->super.s * vi / dmax;
      me->v0 = 0;//We will be starting from rest
    }

    // Now the rest of the "normal" trajectory
    T[1] = me->super.s //How long it takes to accelerate
      * (me->super.s * smax - me->v0) / amax;
    if(T[1] <= 0) { // have to deccelerate all the way, so smax = |vi|
      smax = fabs(vi) * 1.0001f; // avoid aliasing
      continue;//try again
    }
    T[3] = smax / dmax; //How long it takes to deccelerate

    // Constant speed portion fills the rest of the path;
    // maybe < 0 for a short move
    if(T[2] < 0) {
      smax = dmax * (T[3]+T[2]) * 0.999f;//avoid aliasing
      continue;//try again
    }
    break;//all timing constraints met!
  } while(1);

  me->a[0] = me->super.s * dmax;
  me->v[0] = vi;
  me->p[0] = pi;
  
  me->a[1] = me->super.s * amax;
  me->v[1] = me->v[0] + me->a[0]*T[0];
  me->p[1] = me->p[0] + me->v[0]*T[0] + me->a[0]*T[0]*T[0];

  me->a[2] = 0;
  me->v[2] = me->v[1] + me->a[1]*T[1];
  me->p[2] = me->p[1] + me->v[1]*T[1] + me->a[1]*T[1]*T[1];

  me->a[3] = -me->super.s * dmax;
  me->v[3] = me->v[2];
  me->p[3] = me->p[2] + me->v[2]*T[2];

  me->tf[0] = T[0];
  for(int i = 1; i < 4; ++i) me->tf[i] = T[i] + me->tf[i-1];

  { // Will I achieve the desired final position?
    float p4 = me->p[3] + me->v[3]*T[3] + 0.5f*me->a[3]*T[3]*T[3];
    return(fabs(p4 - pf) < convergence);
  }
}

void BangBang1_next(BangBang1* me) {
  float tTot = min(k * period, tf[3]);
  float t;
  if(s == 0) {
    pos = p[3]; vel = 0; acc = 0;
  } else {
    if(tTot == tf[3]) { // the end!
      t = tf[3] - tf[2];
      acc = 0;
      vel = 0;
      pos = p[3] + 0.5f * a[3] * t * t;
    } else if(tTot > tf[2]) { // constant dec
      t = tTot - tf[2];
      acc = a[3];
      vel = v[3] + a[3] * t;
      pos = p[3] + v[2] * t + 0.5f * a[3] * t * t;
    } else if(tTot > tf[1]) { // constant speed
      t = tTot - tf[1];
      acc = 0;
      vel = v[2];
      pos = p[2] + v[2] * t + v[2] * t;
    } else if(tTot > tf[0]) { // constant acc
      t = tTot - tf[1];
      acc = a[1];
      vel = v[1] + a[1] * t;
      pos = p[1] + v[1] * t + 0.5f * a[1] * t * t;
    } else { // dec
      t = tTot;
      acc = a[0];
      vel = v[0] + a[0] * t;
      pos = p[0] + v[0] * t + 0.5f * a[0] * t * t;
    }
  }

  ++me->k;
}