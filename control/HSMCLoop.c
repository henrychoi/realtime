#include "qp_port.h"
#include "HSMCLoop.h"
#ifdef WIN32
# include "win32bsp.h"
#elif defined(__MICROBLAZE__)
# include "bsp.h"
#endif

Q_DEFINE_THIS_FILE

/* Forward declare states that have to be referenced by other states that are
defined earlier in the file.................................................*/
static QState CLoop_off(CLoop*, QEvt const*);

enum InternalSignals {                                  /* internal signals */
    SAMPLE_SIG = MAX_SIG
};

/*..........................................................................*/
QState CLoop_measuring(CLoop* me, QEvt const* e) {
    switch (e->sig) {
    case Q_ENTRY_SIG:
        QTimeEvt_postEvery(&me->timeEvt, (QActive*)me, me->period_in_tick);
        return Q_HANDLED();
    case Q_EXIT_SIG:
        QTimeEvt_disarm(&me->timeEvt);
        return Q_HANDLED();
    case STOP:
        return Q_TRAN(&CLoop_off); /* off state has to be forward declared */
    case SAMPLE_SIG:
        // TODO: read sensors
        return Q_HANDLED();
    }
    return Q_SUPER(&QHsm_top);
}
/*..........................................................................*/
QState CLoop_off(CLoop* me, QEvt const* e) {
    switch (e->sig) {
    case START:
        me->period_in_tick = ((StartEvent*)e)->period_in_tick;
        return Q_TRAN(&CLoop_measuring);
    }
    return Q_SUPER(&QHsm_top);
}
/*..........................................................................*/
QState CLoop_initial(CLoop* me, QEvt const *e) {
    (void)e; /* suppress unused param warning */

    /* Miro declares the QS dictionary in the initial transition.-------------
    But I factored that out to a separate publish method, in case I implement
    re-publishing of the dictionary on (re)connection with QSpy. */
    QActive_subscribe((QActive*)me, START);
    QActive_subscribe((QActive*)me, STOP);

    return Q_TRAN(&CLoop_off);
}
/*..........................................................................*/
void CLoop_ctor(CLoop* me) {
    QActive_ctor(&me->super, (QStateHandler)&CLoop_initial);

    /* CLoop specific initializations --------------------------------------*/
    QTimeEvt_ctor(&me->timeEvt, SAMPLE_SIG);  /* Periodic sample loop event */
}
/*............................................................................
 Static in spirit; i.e. this is like CLoop::publishQSDictionary(). Publish
every item local to this file. It's easier if this is at the end of the file,
so I don't have to forward declare the items (sometimes this is not possible).
*/
void CLoop_declareStaticQSDictionary() {
    /* All instances have same available states */
    QS_FUN_DICTIONARY(&CLoop_initial);
    QS_FUN_DICTIONARY(&CLoop_off);
    QS_FUN_DICTIONARY(&CLoop_measuring);
}
void CLoop_declareInstanceQSDictionary(CLoop* me) {
    QS_SIG_DICTIONARY(SAMPLE_SIG, me);          /* signal just for CLoop */
}
