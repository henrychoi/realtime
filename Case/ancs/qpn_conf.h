#ifndef qpn_conf_h
#define qpn_conf_h

#define Q_NMSM
/* maximum # active objects--must match EXACTLY the QF_active[] definition  */
#define QF_MAX_ACTIVE           2

#define Q_PARAM_SIZE            4
#define QF_MAX_TICK_RATE        1
#define QF_TIMEEVT_CTR_SIZE     2
#define QF_TIMEEVT_PERIODIC     1 //rearm the timer

#define QF_CRIT_ENTRY(dummy)    QF_INT_DISABLE()
#define QF_CRIT_EXIT(dummy)     QF_INT_ENABLE()
#define QF_CRIT_EXIT_NOP()      __asm volatile ("isb")

#endif  /* qpn_conf_h */
