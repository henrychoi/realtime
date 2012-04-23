#include "timespec.h"

/* These constants will exist in the timespec library */
const struct timespec TIMESPEC_ZERO = {0,0}
  , TIMESPEC_ONESEC = {1,0}
  , TIMESPEC_NANOSEC = {0,1}
  , TIMESPEC_MICROSEC = {0,1000}
  , TIMESPEC_MILLISEC = {0,1000000}
;
