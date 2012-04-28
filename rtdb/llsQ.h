#ifndef llsQ_h
#define llsQ_h

#ifdef __cplusplus
extern "C" {
#endif
  /* SINGLE writer, SINGLE reader queue */
  struct llsQ;
  void llsQ_delete(struct llsQ* me);
  struct llsQ* llsQ_new(unsigned char exponent);
  unsigned char llsQ_push(struct llsQ* me, void* node);
  unsigned char llsQ_pop(struct llsQ* me, void** node);

#ifdef __cplusplus
}
#endif

#endif/* llsQ_h */
