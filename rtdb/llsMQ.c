#include <stdlib.h> /* malloc */
#include <string.h> /* memcpy */
#include "llsMQ.h"

#define alignSize(size, alignment) \
  (((size) + ((alignment) - 1)) & ~((alignment) - 1))

void llsMQ_dispose(struct llsMQ* me) {
  me->_size = me->_head = me->_tail = 0;
}
unsigned char llsMQ_init(struct llsMQ* me) {
  me->_head = me->_tail = 0;
  return 1;
}
void llsMQ_free(struct llsMQ* me) {
  llsMQ_dispose(me);
  free(me->_pool); me->_pool = NULL;
}
unsigned char llsMQ_alloc(struct llsMQ* me, unsigned char exponent
			 , size_t memsize, size_t alignment) {
  if(!exponent) return 0;
  me->_size = (1 << exponent) - 1;
  me->_memsize = alignSize(memsize, alignment);
  if(alignment < sizeof(void*))
    alignment = sizeof(void*);
  if(posix_memalign(&me->_pool, alignment, me->_memsize * me->_size)) {
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
  if(!exponent)
    return NULL;
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
unsigned char llsMQ_push(struct llsMQ* me, void* node) {
  size_t head = me->_head;
  if(((head+1) & me->_size) == me->_tail) { /* full */
    return 0;
  } else { /* have to copy; pool <-- node */
    memcpy(me->_pool + (head & me->_size) * me->_memsize, node
	   , me->_memsize);
    me->_head = (head+1) & me->_size;
    return 1;
  }
}
unsigned char llsMQ_pop(struct llsMQ* me, void* node) {
  size_t tail = me->_tail;
  if(me->_head == tail) {
    return 0; /* empty */
  } else { /* have to copy; node <-- pool */
    memcpy(node, me->_pool + (tail & me->_size) * me->_memsize
	   , me->_memsize);
    me->_tail = (tail+1) & me->_size;
    return 1;
  }
}
