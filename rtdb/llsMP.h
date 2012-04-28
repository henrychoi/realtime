#ifndef llsMP_h
#define llsMP_h

#ifdef __cplusplus
extern "C" {
#endif

#define llsMP_align_address(location, alignment) \
  (void *)((((size_t)(location)) + ((alignment) - 1)) & ~((alignment) - 1))
#define llsMP_align_size(size, alignment) \
  (((size) + ((alignment) - 1)) & ~((alignment) - 1))
#define llsMP_alignment_valid(alignment) \
  (((alignment) & (-alignment)) == (alignment))
  /*#define llsMP_alignmentof(testType)			\
    offsetof(struct { char c; testType member; }, member)*/

#ifdef __cplusplus
}
#endif

#endif/* llsMP_h */
