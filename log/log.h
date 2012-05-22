#ifndef log_h
#define log_h
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif//__cplusplus
  enum {
    FATAL = 0,
    ALERT, CRIT, ERROR, WARN, NOTICE, INFO, DEBUG
  };
  extern unsigned char log_level;

#define log_fatal printf
#define log_alert if(log_level >= ALERT) printf
#define log_crit if(log_level >= CRIT) printf
#define log_error if(log_level >= ERROR) printf
#define log_warn if(log_level >= WARN) printf
#define log_notice if(log_level >= NOTICE) printf
#define log_info if(log_level >= INFO) printf
#define log_debug if(log_level == DEBUG) printf

#ifdef __cplusplus
}
#endif//__cplusplus

#endif//log_h
