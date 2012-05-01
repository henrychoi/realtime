#include <stdio.h> /* for snprintf */
#include "timespec.h"

/* These constants will exist in the timespec library */
const struct timespec TIMESPEC_ZERO = {0,0}
  , TIMESPEC_SEC = {1,0}
  , TIMESPEC_NANOSEC = {0,1}
  , TIMESPEC_MICROSEC = {0,1000}
  , TIMESPEC_MILLISEC = {0,1000000}
;

const char* timespec_toString(const struct timespec* t, char* s,
			      float multiplier, unsigned int decimal) {
  char fmt[8];
  sprintf(fmt, "%%.%df", decimal);
  snprintf(s, TIMESPEC_STRING_LEN, fmt,
	   (multiplier) * ((t)->tv_sec + (float)(t)->tv_nsec/1E9f));
  return s;
}

