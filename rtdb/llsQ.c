#include <stdlib.h>
#include "llsQ.h"
struct llsQ {
  unsigned int _size, _mask, _head, _tail;
  void* _q[];
};
void llsQ_delete(struct llsQ* me) {
  free(me);
}
struct llsQ* llsQ_new(unsigned char exponent) {
  unsigned int size = 1 << exponent;
  struct llsQ* me = (struct llsQ*)malloc(sizeof(*me) + size);
  me->_size = size;
  me->_mask = size - 1;
  me->_head = me->_tail = 0;
  return me;
}
unsigned char llsQ_push(struct llsQ* me, void* node) {
  unsigned int head = me->_head;
  if((head++) & me->_mask == me->_tail) /* full */
    return 0;
  else {
    me->_q[head] = node;
    me->_head = head;
    return 1;
  }
}
unsigned char llsQ_pop(struct llsQ* me, void** node) {
  unsigned int tail = me->_tail;
  if(me->_head == tail)
    return 0; /* empty */
  else {
    *node = me->_q[tail];
    me->_tail = (++tail) & me->_mask;
    return 1;
  }
}
