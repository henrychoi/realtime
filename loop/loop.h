#ifndef loop_h
#define loop_h
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*WorkFunction)(void*);

struct Worker {
  unsigned char id;
  WorkFunction work;
  struct llsMQ q;
  unsigned somekindofdata[10];
};

#ifdef __cplusplus
}
#endif

#endif/* loop_h */
