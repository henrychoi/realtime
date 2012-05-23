#include <stdio.h>
#include <math.h>
#include <algorithm>
#include "log/log.h"
#include "control/estimator.h"

using namespace std; // for min()

bool Lowpass::reset(float initial, float hz, float pd
		    , unsigned outlierThreshold) {
  bool ok = true;
  estimator::reset();
  mean = 0, sigma = 0;
  outliers = 0;
  k = 0;
  cutoffhz = hz;
  period = pd;
  outlier_sigma = outlierThreshold;

  // Sanity check
  if(order >= window) {
    log_fatal("Filter order %d >= window %d\n", order, window);
    ok = false;
  }

  if(order) {
    if(cutoffhz > 1/period) {/* Cut-off frequency should be at most
				1/10th sampling rate */
      log_fatal("Cutoff freq %f > 10%% * sampling rate %f\n"
		   , cutoffhz, 1/period);
      ok = false;
    } else if(cutoffhz < 0.001f/period) {
      // Likewise, cut-off frequency should be at least 1/1000th
      // the sampling frequency or else we'll get into numerical problems,
      // especially with higher order filters.
      log_fatal("Cutoff freq %f < 0.1%% * sampling rate %f\n"
		   , cutoffhz, 1/period);
      ok = false;
    }
  }

  // Compute coeff
  float alpha = exp(-2.0f * M_PI * cutoffhz * period);
  dwindow = max((size_t)(.2f/(cutoffhz * period)), 1U);
  dwindow = min(dwindow, window-1);

  switch(order) {
  case 0: a[0] = 1.0f;     b[0] = 1.0f; break;
  case 1:
    a[0] = 1;              b[0] = 1 - alpha;
    a[1] = alpha;          b[1] = 0;
    break;
  case 2://2nd-order is simply implemented as convolution of 2 1st-order
    a[0] = 1;              b[0] = pow((1-alpha),2);
    a[1] = 2*alpha;        b[1] = 0;
    a[2] = -alpha*alpha;   b[2] = 0;
    break;
  case 3://Similarly, a 3rd-order is convolution of 3 1st-order filters
    a[0] = 1;              b[0] = pow((1 - alpha),3);
    a[1] = 3*alpha;        b[1] = 0;
    a[2] = -3*alpha*alpha; b[2] = 0;
    a[3] = pow(alpha, 3);  b[3] = 0;
    break;
  default:
    log_fatal("Estimator order %d unimplemented\n", order);
    ok = false;
  }

  if(isnan(initial)) {
    log_fatal("Initial is NAN\n");
  }
  update(initial);
  return ok;
}

bool Lowpass::update(float input) {
  if(isnan(input)
     || (k > window
	 && (sigma
	     && fabs(input - mean) > (outlier_sigma * sigma)))) {
    if(++outliers > window/2) {
      //reset(hz, period);
      return false;//bad!
    }
    z[k] = y[k-1]; //just use the history or initial in outlier case
  } else { //back to normal
    outliers = 0;
    z[k] = input;
  }

  x[k] = z[k];//latest measurement
 
  if(k < (window-1)) {//If insufficient sample, do not apply the filter
    y[k] = x[k];
  } else {
    size_t j;
    // take the average over a window up to window size
    for(j = k - window + 1, mean = 0; j <= k; ++j) {
      mean += x[j];
    } mean /= window;

    float var = 0;
    for(j = k - window + 1, var = 0; j <= k; ++j) {
      var += (x[j] - mean) * (x[j] - mean);
    } var /= window, sigma = pow(var, 0.5f);

    /* Update the estimator output, i.e.,
       y[k] = a[1]y[k-1] + ... + a[n]y[k-n] + b[0]z[k] + ... + b[n]*z[k-n]
    */
    for(y[k] = b[0] * z[k], j = 1; j <= order; ++j) {
      y[k] += a[j] * y[k-j] + b[j] * z[k-j];
    }
    xdote = (y[k] - y[k - dwindow]) / (dwindow * period);
  }
  xe = y[k];

  ++k;
  return true;
}
