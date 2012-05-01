#include <stdlib.h>
#include "llsMP.h"

#define alignAddress(location, alignment) \
  (void *)((((size_t)(location)) + ((alignment) - 1)) & ~((alignment) - 1))
#define alignSize(size, alignment) \
  (((size) + ((alignment) - 1)) & ~((alignment) - 1))
#define alignmentValid(alignment) \
  (((alignment) & (-alignment)) == (alignment))

void llsMP_dispose(struct llsMP* me) {
  me->_available = me->_capacity = 0;
}
unsigned char llsMP_init(struct llsMP* me, size_t capacity, size_t memsize) {
  size_t j = capacity - 1;

  if(!capacity)
    return 0;

  /* At first, the book points to increasing address within the pool */
  do {
    me->_book[j] = me->_pool + j * memsize;
  } while(j--);

  me->_available = me->_capacity = capacity;

  return 1;
}
void llsMP_free(struct llsMP* me) {
  llsMP_dispose(me);
  free(me->_book); me->_book = NULL;
  free(me->_pool); me->_pool = NULL;
}
unsigned char llsMP_alloc(struct llsMP* me,
			  size_t capacity, size_t memsize, size_t alignment) {
  if(!(me->_book = (void**)malloc(capacity * sizeof(void*)))) {
    return 0;
  }
  memsize/*me->_memSize*/ = alignSize(memsize, alignment);
  if(alignment < sizeof(void*)) alignment = sizeof(void*);
  /*me->_memAlignment = alignment;*/
  if(posix_memalign(&me->_pool, alignment, memsize * capacity)) {
    free(me->_book);
    return 0;
  }
  if(!llsMP_init(me, capacity, memsize)) {
    llsMP_free(me);
    return 0;
  }
  return 1;
}
void llsMP_delete(struct llsMP* me) {
  llsMP_dispose(me);
  free(me->_pool);
  free(me);
}
struct llsMP* llsMP_new(size_t capacity, size_t memsize, size_t alignment) {
  struct llsMP* me = NULL;
  if(!(me = (struct llsMP*)malloc(sizeof(*me)))) {
    return NULL;
  }
  if(!(llsMP_alloc(me, capacity, memsize, alignment))) {
    free(me);
    return NULL;
  }  
  if(!llsMP_init(me, capacity, memsize)) {
    llsMP_free(me);
    return NULL;
  }
  return me;
}

void* llsMP_get(struct llsMP* me) {
  void* node = NULL;
  /* Lock here if changing to a lock implementation ************/
  if(!me->_available) { /* Ran out; alarm! */
    node = NULL;
  } else {
    node = me->_book[--me->_available];
  }
  /* Unlock here if changing to a lock implementation *********/
  return node;
}
unsigned char llsMP_return(struct llsMP* me, void* node) {
  unsigned char ok = 1;
  /* Lock here if changing to a lock implementation ************/
  if(me->_available < me->_capacity) {
    me->_book[me->_available++] = node;
  } else { /* should raise an exception */
    ok = 0;
  }
  /* Unlock here if changing to a lock implementation *********/
  return ok;
}

