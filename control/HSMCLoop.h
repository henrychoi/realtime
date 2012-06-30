#ifndef HSMCLoop_h
#define HSMCLoop_h
enum HSMCLoopSignals {
    START_SIG = Q_USER_SIG /* Public signals the control loop handles. */
    , STOP_SIG /* May be published by BSP to terminate the application */
    , MAX_PUB_SIG /* the last published signal; anything after this are sent
                   * directly from one HSM to another-----------------------*/

    , MAX_SIG /* The last signal is not an actual signal, but a way to count
               * the total number of signals.  Internal signals start at this
               * number */
};

/* Active object class -----------------------------------------------------*/
typedef struct CLoopTag {
    QActive super;
    uint8_t period_in_tick;
    QTimeEvt timeEvt;                        /* for control loop tick event */
} CLoop;

void CLoop_ctor(CLoop* me);
void CLoop_declareStaticQSDictionary();
void CLoop_declareInstanceQSDictionary(CLoop* me);

typedef struct StartEventTag {
    QEvt super;                                    /* derives from QEvt */
    uint8_t period_in_tick;// This is WRT the QF tick, which the BSP decides.
} StartEvent;

#endif//HSMCLoop_h