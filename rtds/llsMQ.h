#ifndef llsMQ_h
#define llsMQ_h
/*Since I am copying memory, I don't need to worry about alignment
#include <stddef.h>
#ifndef alignmentof
#define alignmentof(_testType_) \
  offsetof(struct { char c; _testType_ _testMem; }, _testMem)
#endif
*/

#ifdef __cplusplus
extern "C" {
#endif
  /* SINGLE writer, SINGLE reader queue */
  typedef struct llsMQ {
    size_t _head, _tail, _memsize, _mask;
    void* _pool;/* correctly aligned memory pool */
  } llsMQ;


  unsigned char llsMQ_alloc(struct llsMQ* me, unsigned char exponent
			    , size_t memsize);
  void llsMQ_free(struct llsMQ* me);

  struct llsMQ* llsMQ_new(unsigned char exponent, size_t memsize);
  void llsMQ_delete(struct llsMQ* me);

  unsigned char llsMQ_push(struct llsMQ* me, void* node);
  unsigned char llsMQ_pop(struct llsMQ* me, void* node);

#ifdef __cplusplus
}
#endif

#endif/* llsMQ_h */
