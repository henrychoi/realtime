#include "platform/all.h"
#include <math.h>
#include <float.h>
#include <stdlib.h>
#include "control/sensor.h"

BadThermalSensor::BadThermalSensor(Thermal& device
				   , float noise, float badFraction)
: device(device)
, noise(noise)
  , badThreshold((int)(badFraction * RAND_MAX)) {
}
float BadThermalSensor::read() {
  return (rand() > badThreshold)
    ? device.T + noise * ((float)rand()/RAND_MAX - 0.5f)
    : NAN;
};

