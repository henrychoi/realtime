#ifndef llsMP_h
#define llsMP_h

#ifndef __cplusplus
#  ifndef __alignof__ /* g++ has this */
#    include <stddef.h> /* for offsetof */
#    define __alignof__(testType) \
  offsetof(struct { char c; testType _testMem; }, _testMem)
#  endif
#else
extern "C" {
#endif

typedef struct llsMP {
  size_t _capacity, _available;
  /*size_t _memSize; including alignment*/
  void* _pool;/* the memory itself */
  void* *_book;/* Array for book keeping, but don't know the size till ctor */
} llsMP;

  unsigned char llsMP_alloc(struct llsMP* me,
			    size_t capacity, size_t memsize, size_t alignment);
  void llsMP_free(struct llsMP* me);

  struct llsMP* llsMP_new(size_t capacity, size_t memsize, size_t alignment);
  void llsMP_delete(struct llsMP* me);

  void* llsMP_get(struct llsMP* me);
  unsigned char llsMP_return(struct llsMP* me, void* node);

#ifdef __cplusplus
}
#endif

#endif/* llsMP_h */
