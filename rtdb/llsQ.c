#include <stdlib.h>
#include "llsQ.h"

void llsQ_dispose(struct llsQ* me) {
  me->_size = me->_head = me->_tail = 0;
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
  if(!exponent) /* empty queue */
    return 0;
  me->_size = (1 << exponent) - 1;
  if(!(me->_q = (void* *)malloc(sizeof(void*) * (me->_size)))) {
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
  if(!exponent) return NULL;
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
/* Concrete cases
  exponent                              1    2     3
  q size                               b1  b11  b111
  ---------------------------------------+----+-----+-
  push(1)
    _head                              b0  b00  b000
    _tail                              b0  b00  b000
    head+1                             b1  b01  b001
    (head+1) & size                    b1  b01  b001
    (head+1) & size == _tail            F    F     F
    write index: head & size           b0  b00  b000
    _head becomes                      b1  b01  b001
  push(2) what happens?
    _head                              b1  b01  b001
    _tail                              b0  b00  b000
    head+1                            b10  b10  b010
    (head+1) & size                    b0  b10  b010
    (head+1) & size == _tail            T    F     F
    write index: head & size           NA  b01  b001
    _head becomes                      NA  b10  b010
  pop(1) what happens?
    _head                              b1  b10  b010
    _tail                              b0  b00  b000
    _head == tail                       F    F     F
    read index: tail & size            b0  b00  b000
    (tail+1) & size                    b1  b01  b001
  pop(2) what happens?
    _head                              b1  b10  b010
    _tail                              b1  b01  b001
    _head == tail                       T    F     F
    read index: tail & size            NA  b01  b001
    (tail+1) & size                    NA  b10  b010
  push(3) in this state?
    _head                              b0  b10  b010
    _tail                              b0  b10  b010
    head+1                             b1  b11  b011
    (head+1) & size                    b1  b11  b011
    (head+1) & size == _tail            F    F     F
    write index: head & size           b0  b10  b010
    _head becomes                      b1  b11  b011
  pop(3) what happens?
    _head                              b1  b11  b011
    _tail                              b0  b10  b010
    _head == tail                       F    F     F
    Read index: tail & me->_size       b0  b10  b010
    (tail+1) & size                    b1  b11  b011
  3 consecutive pushes?
    _head                              b1  b10  b010
    _tail                              b0  b00  b000
    head+1                            b10  b11  b011
    (head+1) & size                    b0  b11  b011
    (head+1) & size == _tail            T    F     F
    write index: head & size           NA  b10  b010
    _head becomes                      NA  b11  b011
  4 consecutive pushes?
    _head                              b1  b11  b011
    _tail                              b0  b00  b000
    head+1                            b10 b100  b100
    (head+1) & size                    b0  b00  b100
    (head+1) & size == _tail            T    T     F
    write index: head & size           NA   NA  b011
    _head becomes                      NA   NA  b100
*/
unsigned char llsQ_push(struct llsQ* me, void* node) {
  size_t head = me->_head;
  if(((head+1) & me->_size) == me->_tail) { /* full */
    return 0;
  } else {
    me->_q[head & me->_size] = node;
    me->_head = (head+1) & me->_size;
    return 1;
  }
}
unsigned char llsQ_pop(struct llsQ* me, void** node) {
  size_t tail = me->_tail;
  if(me->_head == tail) { /* empty */
    return 0;
  } else {
    *node = me->_q[tail & me->_size];
    me->_tail = (tail+1) & me->_size;
    return 1;
  }
}
