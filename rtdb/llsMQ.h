#ifndef llsMQ_h
#define llsMQ_h

#ifdef __cplusplus
extern "C" {
#endif
  /* SINGLE writer, SINGLE reader queue */
  typedef struct llsMQ {
    size_t _head, _tail, _memsize, _mask;
    void* _pool;/* correctly aligned memory pool */
  } llsMQ;

#ifndef alignmentof
#define alignmentof(testType) \
  offsetof(struct { char c; testType _testMem; }, _testMem)
  /*(sizeof(struct { char c; testType _testMem; }) - sizeof(testType))*/
#endif

  unsigned char llsMQ_alloc(struct llsMQ* me, unsigned char exponent
			    , size_t memsize, size_t alignment);
  void llsMQ_free(struct llsMQ* me);

  struct llsMQ* llsMQ_new(unsigned char exponent, size_t memsize, size_t alignment);
  void llsMQ_delete(struct llsMQ* me);

  unsigned char llsMQ_push(struct llsMQ* me, void* node);
  unsigned char llsMQ_pop(struct llsMQ* me, void* node);

#ifdef __cplusplus
}
#endif

#endif/* llsMQ_h */
