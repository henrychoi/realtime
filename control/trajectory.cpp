#include <string.h>
#include <math.h>
#include <algorithm>
#include "control/trajectory.h"

using namespace std;
bool BangBang1::reset(float period, float convergence
    , float pi, float pf
    , float vi, float smax
    , float amax, float dmax)
{
  float T[4]; memset(T, 0, sizeof(T));
  k = 0;
  this->period = period;
  this->vi = vi;

  p[0] = pi;// I will always start from current position

  // Firstly, which direction am I going?
  if(pf > pi) s = 1.f;
  else if(pf < pi) s = -1.f;
  else {
    if(vi == 0) { // trivial case: no movement
      s = 0;
      memset(a, 0, sizeof(a));
      p[0] = p[1] = p[2] = p[3] = pi;
      return true;
    } else {//Need to go the other way from current velocity
		s = -fsign(vi);
    }
  }

  // Invariant: sign != 0 at this point
  do { // iterate until all timing constraints are met
    if(vi * s > 0) {// Is the initial velocity the same sign as s?
      T[0] = 0;
      //p[1] = p[0];
      v0 = vi;
    } else {//If not, slow down first
      T[0] = -s * vi / dmax;
      v0 = 0;//We will be starting from rest
    }

    // Now the rest of the "normal" trajectory
    T[1] = s * (s * smax - v0) / amax;//How long it takes to accelerate
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
  } while(true);

  a[0] = s * dmax;
  v[0] = vi;
  p[0] = pi;
  
  a[1] = s * amax;
  v[1] = v[0] + a[0]*T[0];
  p[1] = p[0] + v[0]*T[0] + a[0]*T[0]*T[0];

  a[2] = 0;
  v[2] = v[1] + a[1]*T[1];
  p[2] = p[1] + v[1]*T[1] + a[1]*T[1]*T[1];

  a[3] = -s * dmax;
  v[3] = v[2];
  p[3] = p[2] + v[2]*T[2];
  float p4 = p[3] + v[3]*T[3] + 0.5f*a[3]*T[3]*T[3];

  tf[0] = T[0];
  for(int i = 1; i < 4; ++i) tf[i] = T[i] + tf[i-1];

  // Will I achieve the desired final position?
  return(fabs(p4 - pf) < convergence);
}

void BangBang1::next() {
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

  ++k;
}