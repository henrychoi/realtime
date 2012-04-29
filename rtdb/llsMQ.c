#include <stdlib.h> /* malloc */
#include <string.h> /* memcpy */
#include "llsMQ.h"

#define alignSize(size, alignment) \
  (((size) + ((alignment) - 1)) & ~((alignment) - 1))

void llsMQ_dispose(struct llsMQ* me) {
  me->_size = me->_mask = me->_head = me->_tail = 0;
}
unsigned char llsMQ_init(struct llsMQ* me) {
  me->_mask = (me->_size << 1) - 1;
  me->_head = me->_tail = 0;
  return 1;
}
void llsMQ_free(struct llsMQ* me) {
  llsMQ_dispose(me);
  free(me->_pool); me->_pool = NULL;
}
unsigned char llsMQ_alloc(struct llsMQ* me, unsigned char exponent
			 , size_t memsize, size_t alignment) {
  me->_memsize = alignSize(memsize, alignment);
  if(alignment < sizeof(void*)) alignment = sizeof(void*);
  me->_size = 1 << exponent;
  if(posix_memalign(&me->_pool, alignment, memsize)) {
    me->_size = 0;
    return 0;
  }
  if(!llsMQ_init(me)) {
    llsMQ_free(me);
    return 0;
  }
  return 1;
}
void llsMQ_delete(struct llsMQ* me) {
  llsMQ_dispose(me);
  free(me);
}
struct llsMQ* llsMQ_new(unsigned char exponent, size_t memsize, size_t alignment) {
  struct llsMQ* me = NULL;
  if(!(me = (struct llsMQ*)malloc(sizeof(*me)))) {
    return NULL;
  }
  if(!(llsMQ_alloc(me, exponent, memsize, alignment))) {
    free(me);
    return NULL;
  }  
  if(!llsMQ_init(me)) {
    llsMQ_free(me);
    return NULL;
  }
  return me;
}
/*
  exponent                              0    1     2
  ---------------------------------------+----+-----+-
  q size                                1    2     4
  _mask                                b1  b11  b111
  push(1)
    _head                              b0  b00  b000
    _tail                              b0  b00  b000
    head+1                             b1  b01  b001
    (head+1) & _mask                   b1  b01  b001
    (head+1) & _mask == _tail           F    F     F
    _head becomes                      b1  b01  b001
  push(2) what happens?
    _head                              b1  b01  b001
    _tail                              b0  b00  b000
    head+1                            b10  b10  b010
    (head+1) & _mask                   b0  b10  b010
    (head+1) & _mask == _tail           T    F     F
    _head becomes                      b1  b10  b010
  pop(1) what happens?
    _head                              b1  b10  b010
    _tail                              b0  b00  b000
    Reading this index from pool is    OK   OK    OK
    _head == tail                       F    F     F
    _tail becomes                      b1  b01  b001
  pop(2) what happens?
    _head                              b1  b10  b010
    _tail                              b1  b01  b001
    _head == tail                       T    F     F
    Reading _tail index from pool is   NA   OK    OK
    _tail becomes                      b1  b10  b010
  push(3), what happens?
    _head                              b1  b10  b010
    _tail                              b1  b10  b010
    head+1                            b10  b10  b010
    (head+1) & _mask                   b0  b10  b010
    Write index: head & (_mask >> 1)   b0  b01  b001
    (head+1) & _mask == _tail           F    F     F
    _head becomes                      b0  b11  b011
  pop(3) what happens?
    _head                              b0  b11  b011
    _tail                              b1  b10  b010
    _head == tail                       F    F     F
    Read index: tail & (me->_mask>>1)  b0  b00  b010
    Reading read index from pool is    OK   OK    OK
    _tail becomes                      b0  b11  b011
*/
unsigned char llsMQ_push(struct llsMQ* me, void* node) {
  size_t head = me->_head;
  if((head+1) & me->_mask) == me->_tail) { /* full */
    return 0;
  } else { /* have to copy; pool <-- node */
    memcpy(me->_pool + head * me->_memsize, node, me->_memsize);
    me->_head = (head+1) & me->_mask;
    return 1;
  }
}
unsigned char llsMQ_pop(struct llsMQ* me, void* node) {
  size_t tail = me->_tail;
  if(me->_head == tail) {
    return 0; /* empty */
  } else { /* have to copy; node <-- pool */
    memcpy(node, me->_pool + tail * me->_memsize, me->_memsize);
    me->_tail = (tail+1) & me->_mask;
    return 1;
  }
}
