#ifndef qpn_conf_h
#define qpn_conf_h

#define Q_NMSM
/* maximum # active objects--must match EXACTLY the QF_active[] definition  */
#define QF_MAX_ACTIVE           1

#define Q_PARAM_SIZE            4
#define QF_MAX_TICK_RATE        1
#define QF_TIMEEVT_CTR_SIZE     2
#define QF_TIMEEVT_PERIODIC     1 //rearm the timer

#define QF_CRIT_ENTRY(dummy)    QF_INT_DISABLE()
#define QF_CRIT_EXIT(dummy)     QF_INT_ENABLE()
#define QF_CRIT_EXIT_NOP()      __asm volatile ("isb")

//#define Q_ROM

#if 0
typedef char char_t;
typedef int int_t;
typedef int enum_t;
typedef float float32_t;
typedef double float64_t;
#endif

#endif  /* qpn_conf_h */
