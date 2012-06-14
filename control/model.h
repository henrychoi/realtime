#ifndef model_h
#define model_h

class Elevator {
public:
  float x, xdot, period, CW, M, disturb;
	Elevator(float period, float CW, float M, float disturb)
    : period(period), CW(CW), M(M), disturb(disturb) {};
  bool update(float motor);
};

class Thermal {
public:
  float T, period, R, C, disturb;
  Thermal(float period, float initial, float R, float C, float disturb)
    : T(initial), period(period), R(R), C(C), disturb(disturb) {};
  bool update(float qin, float ambient);
};

#endif//model_h