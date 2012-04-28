#include <stdlib.h>
#include "llsMP.h"

struct llsMP {
  size_t _memSize/*including alignment*/, _memAlignment, _capacity;
  void* _pool;
  /* The stack here is the array of pointers */
  void **_sp, *_sb[];
};

#if 0
void llsMP_delete(struct llsMP* me) {
 
}
void* allocatePool(size_t size, size_t alignment) {
  if(alignment < sizeof(void*)) alignment = sizeof(void*);
  return memalign(alignment, size);
}
struct llsMP* llsMP_new(size_t capacity, size_t memsize, size_t alignment) {
  
  me->_memSize = align_size(memsize, alignment);
  me->_memAlignment = alignment;
  me->_pool = allocatePool(capacity * me->_memsize, me->_memAlignment);
  me->_sb = (void**)calloc(capacity, sizeof(void*));
  void** ptr = me->_sb;
  *ptr = (void*) ( (size_t)me->_pool + (capacity-1) * me->_memSize );
  for(j = 0; j < capacity - 1; ++j, ++ptr)
    *(ptr + 1) = (void*) ( ((size_t) *(ptr)) - me->_memSize);

  pool->sp = ptr;

  me->_capacity = capacity;
}
void* llsMP_get(struct llsMP* me) {
  void* node = NULL;
  /* Lock here if changing to a lock implementation ************/
  if(me->_sp >= me->_sb) { /* */
    node = *((me->_sp)--);
  } else { /* Ran out; alarm! */
    node = NULL;
  }
  /* Unlock here if changing to a lock implementation *********/
  return node;
}
void llsMP_return(struct llsMP* me, void* node) {
  /* Lock here if changing to a lock implementation ************/
  *(++(me->_sp)) = node;
  /* Unlock here if changing to a lock implementation *********/
}
#endif
