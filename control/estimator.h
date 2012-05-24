#ifndef estimator_h
#define estimator_h

#include <stdlib.h>//for size_t
#include "rtds/ring.h"

class estimator {
 public:
  virtual bool update(float input) = 0;
  float xe, xdote;
  void reset() { xdote = 0; }
};

class ScalarLowpass : public estimator { // a low pass filter
 protected:
  size_t k, order, outliers, dwindow, window, outlier_sigma;
  Ring<float> x //to calculate sample variance
    , y, z, a, b;/* These variable names follow standard digital filtering
		    notation, a[0]y[k]
		    = a[1]*y[k-1] + ... + a[n]*y[k-n]
		    + b[0]*z[k] + ... + b[m]*z[k-m]
		    where
		    z[i] = measurements
		    y[i] = filter outputs
		    n = filter order
		 */
 public:
 ScalarLowpass(size_t window = 20, size_t order = 1)
   : window(window), order(order)
    , x(window), y(window), z(window), a(order+1), b(order+1)
    {};
  float mean, sigma, period, cutoffhz;
  bool update(float input);
  bool reset(float initial, float hz, float sampling_period
	     , unsigned outlier_sigma = 10);
};

#endif//estimator_h
