#ifndef loop_h
#define loop_h

#include "rtds/pipe.h"

template<typename STimeType, typename UTimeType>
class LoopData { /* the node I am going to shove into q */
 public:
  STimeType jitter;
  UTimeType t_work, deadline, period;
  unsigned long long count;
};

template<typename Thread, typename STime, typename UTime>
class Loop {
 public:
  unsigned char id;
  char name[20];
  Thread thread;
  Pipe< LoopData<STime, UTime> > loopdata_q, late_q;

  virtual ~Loop() {};
 Loop() : loopdata_q(30), late_q(10) {};
  void work();
};

#endif//loop_h
