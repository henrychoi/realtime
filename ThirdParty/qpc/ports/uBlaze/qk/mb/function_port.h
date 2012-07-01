#ifndef function_port_h
#define function_port_h
#ifndef MIN
# define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
# define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

#ifndef memcpy
# define memcpy(dst, src, l) do { int i_; /* yes, this is slow */ \
	for(i_ = 0; i_ < (l); i_++) ((char*)(dst))[i_] = ((char*)(src))[i_]; \
  } while(0)
#endif

#endif//function_port_h
