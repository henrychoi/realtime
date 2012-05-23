#ifndef sensor_h
#define sensor_h

class sensor {
 public:
  virtual float read() = 0;
};

#include "control/model.h"

class BadThermalSensor : public sensor {
 protected:
  Thermal& device;
  float noise;
  int badThreshold;
 public:
  float read();
  BadThermalSensor(Thermal& device, float noise, float badFraction);
};

#endif//sensor_h
