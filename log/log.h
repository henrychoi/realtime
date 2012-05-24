#ifndef log_h
#define log_h
#include <stdio.h>

typedef enum {
  FATAL = 0,
  ALERT, CRIT, ERROR, WARN, NOTICE, INFO, DEBUG
} LogLevel;
extern LogLevel log_level;
extern FILE* log_file;

inline int log_f(const char* ctx
		 , const char* level, const char* pf, const char* message)
{
  return fprintf(log_file, "%s,%s,%s,%s\n", level
		 , ctx ? ctx : "UNK", pf, message);
}
inline int log_fatal_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("FATAL", pf, message, ctx);
};
inline int log_alert_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("ALERT", pf, message, ctx);
};
inline int log_crit_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("CRIT", pf, message, ctx);
};
inline int log_error_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("ERROR", pf, message, ctx);
};
inline int log_warn_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("WARN", pf, message, ctx);
};
inline int log_notice_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("NOTICE", pf, message, ctx);
};
inline int log_info_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("INFO", pf, message, ctx);
};
inline int log_debug_f(const char* ctx, const char* pf, const char* message)
{
  return log_f("DEBUG", pf, message, ctx);
};

#define log_fatal(ctx, message)\
  log_fatal_f(ctx, __PRETTY_FUNCTION__, message)

#define log_alert(ctx, message) if(log_level >= ALERT)\
    log_alert_f(ctx, __PRETTY_FUNCTION__, message)

#define log_crit(ctx, message) if(log_level >= CRIT)\
    log_crit_f(ctx, __PRETTY_FUNCTION__, message)

#define log_error(ctx, message) if(log_level >= ALERT)\
    log_error_f(ctx, __PRETTY_FUNCTION__, message)

#define log_warn(ctx, message) if(log_level >= WARN)\
    log_warn_f(ctx, __PRETTY_FUNCTION__, message)

#define log_notice(ctx, message) if(log_level >= NOTICE)\
    log_notice_f(ctx, __PRETTY_FUNCTION__, message)

#define log_info(ctx, message) if(log_level >= INFO)\
    log_info_f(ctx, __PRETTY_FUNCTION__, message)

#define log_debug(ctx, message) if(log_level >= DEBUG)\
    log_debug_f(ctx, __PRETTY_FUNCTION__, message)

#endif//log_h
