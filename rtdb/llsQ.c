#include <stdlib.h>
#include "llsQ.h"

void llsQ_dispose(struct llsQ* me) {
  me->_size = me->_mask = me->_head = me->_tail = 0;
}
unsigned char llsQ_init(struct llsQ* me) {
  me->_mask = (me->_size << 1) - 1;
  me->_head = me->_tail = 0;
  return 1;
}
void llsQ_free(struct llsQ* me) {
  llsQ_dispose(me);
  free(me->_q); me->_q = NULL;
}
unsigned char llsQ_alloc(struct llsQ* me, unsigned char exponent) {
  me->_size = 1 << exponent;
  if(!(me->_q = (void* *)malloc(sizeof(void*) * me->_size))) {
    me->_size = 0;
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
  size_t size = 1 << exponent;
  if(!(me = (struct llsQ*)malloc(sizeof(*me)))) {
    return NULL;
  }
  if(!(llsMQ_alloc(me, exponent))) {
    free(me);
    return NULL;
  }  
  if(!llsQ_init(me)) {
    llsQ_free(me);
    return NULL;
  }
  return me;
}
unsigned char llsQ_push(struct llsQ* me, void* node) {
  size_t head = me->_head;
  if(((head+1) & me->_mask) == me->_tail) { /* full */
    return 0;
  } else {
    me->_q[head & (me->_mask>>1)] = node;
    me->_head = (head+1) & me->_mask;
    return 1;
  }
}
unsigned char llsQ_pop(struct llsQ* me, void** node) {
  size_t tail = me->_tail;
  if(me->_head == tail) { /* empty */
    return 0;
  } else {
    *node = me->_q[tail & (me->_mask>>1)];
    me->_tail = (tail+1) & me->_mask;
    return 1;
  }
}
