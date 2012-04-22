#ifndef timespec_h
#define timespec_h
#include <time.h>
/*
* User-level doesn't have some of these utilities.
* In fact, POSIX entirely ignores the idea of SMP or
* any utility routines for comparing/setting
* timespec values.
* -- Cort <cort@fsmlabs.com>
*/

#ifndef CONFIG_RTL

#define NSECS_PER_SEC 1000000000

#define timespec_normalize(t) {\
   if ((t) ->tv_nsec >= NSECS_PER_SEC) { \
       (t) ->tv_nsec -= NSECS_PER_SEC; \
       (t) ->tv_sec++; \
   } else if ((t) ->tv_nsec < 0) { \
       (t) ->tv_nsec += NSECS_PER_SEC; \
       (t) ->tv_sec -- ; \
   } \
}

#define timespec_sub(t1, t2) do { \
   (t1) ->tv_nsec -= (t2) ->tv_nsec; \
   (t1) ->tv_sec  -= (t2) ->tv_sec; \
   timespec_normalize(t1); \
} while (0)

#define timespec_add_ns(t,n) do { \
   (t) ->tv_nsec += (n); \
   timespec_normalize(t); \
} while (0)

#define timespec_lt(t1, t2) \
   ((t1) ->tv_sec < (t2) ->tv_sec \
|| ((t1) ->tv_sec == (t2) ->tv_sec && (t1)->tv_nsec < (t2) ->tv_nsec))
#define timespec_nz(t) ((t) ->tv_sec != 0 || (t) ->tv_nsec != 0)

#endif //ndef CONFIG_RTL

/* Convenient constants.  Never modify them
 */
extern const struct timespec TIMESPEC_ZERO, TIMESPEC_ONESEC, TIMESPEC_NANOSEC,
  TIMESPEC_MICROSEC, TIMESPEC_MILLISEC;

#define TIMESPEC_STRING_LEN 16

/*
  Forms a string using floating point calculation.  Note that we do not
  allocate a new string, so the caller must supply a different string
  for each number to convert.

  @param t "this" pointer to struct timespec

  @param s In pointer to char to hold the resultant string.  Must be
  TIMESPEC_STRING_LEN bytes or longer.

  @param multiplier For printing convenience, you may supply a multiplier.
         multiplier of 1f means represent it in seconds.
	 multiplier of 0.001f means in thousands of a second
	 multiplier of 1000.0f means in millisec

  @param decimal

  @return On success, the same pointer as the input pointer, for convenience.
  On failure, NULL.
*/
const char* timespec_toString(const struct timespec* t, char* s,
			      float multiplier, unsigned int decimal);

#endif/* timespec_h */
