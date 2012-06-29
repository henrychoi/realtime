#ifndef HSMCLoop_h
#define HSMCLoop_h
enum HSMCLoopSignals {
    /* Signals emitted by state machines through the publish-subscribe
     * framework */
    TERMINATE_SIG = Q_USER_SIG/* May be published by BSP to terminate the
                               * application */
    , MAX_PUB_SIG /* the last published signal; anything after this are sent
                   * directly from one HSM to another-----------------------*/

    , MAX_SIG /* the last signal is not an actual signal, but a way to count
               * the total number of signals--------------------------------*/
};
#endif//HSMCLoop_h