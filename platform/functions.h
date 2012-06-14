#ifndef platform_functions_h
#define platform_functions_h

#ifdef WIN32
#  include <limits>
#  define snprintf _snprintf_s
#  define platform_fopen fopen_s
#  define isnan _isnan
#  ifndef NAN
#    define NAN std::numeric_limits<float>::quiet_NaN()
#  endif
#else
#  define platform_fopen(fpp, name, mode) *fpp = fopen(name, mode)
#endif//WIN32

#endif//platform_functions_h
