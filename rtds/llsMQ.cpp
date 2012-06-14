#include <stdlib.h> /* malloc */
#include <string.h> /* memcpy */
#include "rtds/llsMQ.h"

#define alignSize(size, alignment) \
  (((size) + ((alignment) - 1)) & ~((alignment) - 1))

void llsMQ_dispose(struct llsMQ* me) {
  me->_mask = me->_head = me->_tail = 0;
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
			  , size_t memsize/*, size_t alignment*/) {
  me->_mask = (1 << (exponent+1)) - 1;
#ifdef ALIGN_MEMORY_NECESSARY
  me->_memsize = alignSize(memsize, alignment);
  if(alignment < sizeof(void*))
    alignment = sizeof(void*);
  if(posix_memalign(&me->_pool, alignment
		    , me->_memsize * (me->_mask + 1) /* 1 more needed */)) {
    return 0;
  }
#else
  me->_memsize = memsize;
  me->_pool = malloc(me->_memsize * (me->_mask + 1));
#endif
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
struct llsMQ* llsMQ_new(unsigned char exponent, size_t memsize
			/*, size_t alignment*/) {
  struct llsMQ* me = NULL;
  if(!(me = (struct llsMQ*)malloc(sizeof(*me)))) {
    return NULL;
  }
  if(!(llsMQ_alloc(me, exponent, memsize/*, alignment*/))) {
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
  if(((me->_head+1) & me->_mask) == me->_tail) { /* full */
    return 0;
  } else { /* have to copy; pool <-- node */
    memcpy((void*)((size_t)me->_pool + me->_head * me->_memsize)//VC++ nonsense
		, node, me->_memsize);
    me->_head = (me->_head+1) & me->_mask;
    return 1;
  }
}
unsigned char llsMQ_pop(struct llsMQ* me, void* node) {
  if(me->_head == me->_tail) {
    return 0; /* empty */
  } else { /* have to copy; node <-- pool */
    memcpy(node
		, (void*)((size_t)me->_pool + me->_tail * me->_memsize)//VC++ nonsense
		, me->_memsize);
    me->_tail = (me->_tail+1) & me->_mask;
    return 1;
  }
}
