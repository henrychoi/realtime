#include <stdio.h> /* for sprintf */
#include "timespec.h"

const struct timespec TIMESPEC_ZERO = {0,0}
  , TIMESPEC_ONESEC = {1,0}
  , TIMESPEC_NANOSEC = {0,1}
  , TIMESPEC_MICROSEC = {0,1000}
  , TIMESPEC_MILLISEC = {0,1000000}
;


const char* timespec_toString(const struct timespec* t, char* s,
			      float multiplier, unsigned int decimal)
{
  char fmt[8];
  sprintf(s, "%%.%df", decimal);
  float numf = multiplier * (t->tv_sec + (float)t->tv_nsec / 1E9f);
  sprintf(s, fmt, numf);
  return s;
}

void test_timespec() {
   char s[TIMESPEC_STRING_LEN];
   struct timespec time = TIMESPEC_ZERO;

   printf("TIMESPEC_ZERO = %s s\n", timespec_toString(&time, s, 1.0f, 3));
   printf("TIMESPEC_ZERO = %s ms\n", timespec_toString(&time, s, 1E3f, 1));
   printf("TIMESPEC_ZERO = %s us\n", timespec_toString(&time, s, 1E6f, 1));

   time = TIMESPEC_ONESEC;
   printf("TIMESPEC_ONESEC = %s s\n", timespec_toString(&time, s, 1.0f, 3));
   printf("TIMESPEC_ONESEC = %s ms\n", timespec_toString(&time, s, 1E3f, 1));
   printf("TIMESPEC_ONESEC = %s us\n", timespec_toString(&time, s, 1E6f, 1));

   timespec_sub(&time, &TIMESPEC_ONESEC);
   printf("-1 s = %s ns\n", timespec_toString(&time, s, 1.0f, 3);

   time = TIMESPEC_ZERO;
   timespec_sub(&time, &TIMESPEC_NANOSEC);
   printf("-1 ns = %s ns\n", timespec_toString(&time, s, 1E9f, 0);

   return 1;
}
