#ifndef llsQ_h
#define llsQ_h

#ifdef __cplusplus
extern "C" {
#endif
  /* SINGLE writer, SINGLE reader queue */
  typedef struct llsQ {
    size_t _size, _mask, _head, _tail;
    void* *_q;/* array of pointers */
  } llsQ;

  unsigned char llsQ_alloc(struct llsQ* me, unsigned char exponent);
  void llsQ_free(struct llsQ* me);

  struct llsQ* llsQ_new(unsigned char exponent);
  void llsQ_delete(struct llsQ* me);

  unsigned char llsQ_push(struct llsQ* me, void* node);
  unsigned char llsQ_pop(struct llsQ* me, void** node);

#ifdef __cplusplus
}
#endif

#endif/* llsQ_h */
