#ifndef qpn_port_h
#define qpn_port_h

#define Q_NFSM//Use HSM instead of FSM
#define Q_PARAM_SIZE 4//32 bits is enough for COLOR & duration
#define QF_TIMEEVT_CTR_SIZE     1

/* maximum # active objects--must match EXACTLY the QF_active[] definition  */
#define QF_MAX_ACTIVE 1

                                /* interrupt locking policy for task level */
#define QF_INT_DISABLE()        __disable_interrupt()
#define QF_INT_ENABLE()         __enable_interrupt()

                            /* interrupt locking policy for interrupt level */
/* #define QF_ISR_NEST */                    /* nesting of ISRs not allowed */

                                         /* interrupt entry and exit for QK */
#define QK_ISR_ENTRY()          ((void)0)
#define QK_ISR_EXIT()           QK_SCHEDULE_()


#include <stdint.h>    /* Exact-width integer types. WG14/N843 C99 Standard */
#include "qepn.h"         /* QEP-nano platform-independent public interface */
#include "qfn.h"           /* QF-nano platform-independent public interface */
#include "qkn.h"           /* QK-nano platform-independent public interface */

#endif                                                        /* qpn_port_h */
