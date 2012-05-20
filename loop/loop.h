#ifndef loop_h
#define loop_h

class Worker {
 public:
  unsigned char id;
  void work() {};
  RT_TASK task;
};

#endif/* loop_h */
