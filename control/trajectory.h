#ifndef control_trajectory
#define control_trajectory

class Trajectory1 {
public:
  float pos, vel, acc// What a scalar trajectory emits
    , period, s;
  virtual void next() = 0;
};
class BangBang1 : public Trajectory1 {
protected:
  float p[4], v[4], a[4];// at the BEGINNING of each phase
public:
  size_t k;
  float vi, v0, tf[4];
  bool reset(float period, float convergence
    , float pinitial, float pfinal
    , float vinitial, float smax
    , float amax, float dmax);
  void next();
};

class Trapezoidal1 : public Trajectory1 {
public:
  size_t k;
  float tf[10];
  bool reset(float period
    , float pinitial, float pfinal
    , float vinitial, float smax
    , float amax, float dmax
    , float jerk);
  void next();
};

#endif//control_trajectory