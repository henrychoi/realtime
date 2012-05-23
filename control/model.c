#include <stdlib.h>
#include "model.h"

bool Elevator::update(float motor) {
  float force = (motor
		 + 9.8 * (CW - M)) // gravity
    + ((float)rand()/RAND_MAX - 0.5f) * disturb;
  xdot += (force/M)  * period; // integrate accleration
  x += xdot * period;
  return true;
}

bool Thermal::update(float qin, float ambient) {
  float dT = (qin
	      - ((T - ambient) / R)
	      + ((float)rand()/RAND_MAX - 0.5f) * disturb) / C;
  T += dT * period;
  return true;
}
