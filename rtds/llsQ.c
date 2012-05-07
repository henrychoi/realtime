#include <stdlib.h>
#include "llsQ.h"

void llsQ_dispose(struct llsQ* me) {
  me->_mask = me->_head = me->_tail = 0;
}
unsigned char llsQ_init(struct llsQ* me) {
  me->_head = me->_tail = 0;
  return 1;
}
void llsQ_free(struct llsQ* me) {
  llsQ_dispose(me);
  free(me->_q); me->_q = NULL;
}
unsigned char llsQ_alloc(struct llsQ* me, unsigned char exponent) {
  me->_mask = (1 << (exponent+1)) - 1;
  if(!(me->_q = (void* *)
       malloc(sizeof(void*) * (me->_mask + 1 /* 1 space is wasted */) ))) {
    return 0;
  }
  if(!llsQ_init(me)) {
    llsQ_free(me);
    return 0;
  }
  return 1;
}
void llsQ_delete(struct llsQ* me) {
  llsQ_dispose(me);
  free(me);
}
struct llsQ* llsQ_new(unsigned char exponent) {
  struct llsQ* me = NULL;
  if(!(me = (struct llsQ*)malloc(sizeof(*me)))) {
    return NULL;
  }
  if(!(llsQ_alloc(me, exponent))) {
    free(me);
    return NULL;
  }  
  if(!llsQ_init(me)) {
    llsQ_free(me);
    return NULL;
  }
  return me;
}
/*
  Note 1 node is wasted to detect queue full
 Invariants:
 * head, tail = [0, 2^(exponent+1) - 1]
Concrete cases
  exponent                              0     1
  _mask                                b1   b11
  ----------------------------------+----+----+
  push(1)
    _head                              b0  b00
    _tail                              b0  b00
    head+1                             b1  b01
    (head+1) & _mask                   b1  b01
    (head+1) & _mask == _tail           F    F
    write index: head                  b0  b00
    _head becomes                      b1  b01
  push(2) what happens?
    _head                              b1  b01
    _tail                              b0  b00
    head+1                            b10  b10
    (head+1) & mask                    b0  b10
    (head+1) & mask == _tail            T    F
    _head becomes                      NA  b10
  pop(1) what happens?
    _head                              b1  b10
    _tail                              b0  b00
    _head == tail                       F    F
    (tail+1) & mask                    b1  b01
  pop(2) what happens?
    _head                              b1  b10
    _tail                              b1  b01
    _head == tail                       T    F
    (tail+1) & mask                    NA  b10
  push(3) in this state?
    _head                              b1  b10
    _tail                              b1  b10
    head+1                            b10  b11
    (head+1) & mask                    b0  b11
    (head+1) & mask == _tail            F    F
    _head becomes                      b0  b11
  pop(3) what happens?
    _head                              b0  b11
    _tail                              b1  b10
    _head == tail                       F    F
    (tail+1) & mask                    b0  b11
*/
unsigned char llsQ_push(struct llsQ* me, void* node) {
  if(((me->_head+1) & me->_mask) == me->_tail) { /* full */
    return 0;
  } else {
    me->_q[me->_head] = node;
    me->_head = (me->_head+1) & me->_mask;
    return 1;
  }
}
unsigned char llsQ_pop(struct llsQ* me, void** node) {
  if(me->_head == me->_tail) { /* empty */
    return 0;
  } else {
    *node = me->_q[me->_tail];
    me->_tail = (me->_tail+1) & me->_mask;
    return 1;
  }
}
