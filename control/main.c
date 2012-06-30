#include "qp_port.h"
#include "HSMCLoop.h"
#ifdef WIN32
# include "win32bsp.h"
#endif

/* Local-scope objects -----------------------------------------------------*/
static QSubscrList l_subscrSto[MAX_PUB_SIG];         /* a list for each sig */
static union SmallEvents {
    void   *e0;                                       /* minimum event size */
    uint8_t e1[sizeof(StartEvent)];
    /* ... other event types to go into this pool */
} l_smlPoolSto[16];/* storage for the small event pool; note the queue storage
                   is just an array */
#define N_CLOOP 1
static CLoop l_cloop[N_CLOOP];                      /* CLoop active objects */
//QActive* const AO_cloop0 = (QActive*)&l_cloop0;
static QEvt const* l_cloopQueueSto[N_CLOOP][8];

/*............................................................................
 QSpy needs a dictionary of all static objects.  Dictionary uses
 preprocessor macro to generate a name, so I can't just invoke each
 instance's dictionary publish method even if it exists.
 */
void declareQSDictionary() {
    uint8_t i;

    /* dictionary avaiable in in this file: --------------------------------*/
    QS_OBJ_DICTIONARY(l_smlPoolSto);

    QS_OBJ_DICTIONARY(&l_cloop[0]);/* All active objects in this app:       */

    QS_FUN_DICTIONARY(&QHsm_top); /* An HSM always has the top pseudo state */

                                                         /* global signals: */
    QS_SIG_DICTIONARY(START_SIG, 0);
    QS_SIG_DICTIONARY(STOP_SIG, 0);

    /* dictionary avaiable in other files: ---------------------------------*/
    CLoop_declareStaticQSDictionary(); /* The static dictionary */
    for(i = 0; i < N_CLOOP; ++i) { /* Per instance dictionary */
        CLoop_declareInstanceQSDictionary(&l_cloop[i]);
    }
}
/*..........................................................................*/
int main(
#ifdef WIN32
    int argc, char *argv[]
#endif
) {
    uint8_t i;
    for(i = 0; i < N_CLOOP; ++i) {/* Instantiate the control loop active
                                  objects; this is unnecessary in C++, as the
                                  ctor is called even for a static object */
        CLoop_ctor(&l_cloop[i]);
    }

#ifdef WIN32
    BSP_init(argc, argv);           /* initialize the Board Support Package */
#elif defined(__MICROBLAZE__)
    BSP_init();
#endif
    QF_init();     /* initialize the framework and the underlying RT kernel */
    declareQSDictionary();/* TODO: send object dictionaries on (re)connection
                           * with QSpy */
    QF_psInit(l_subscrSto, Q_DIM(l_subscrSto));   /* init publish-subscribe */
                                    /* initialize event pools; NOTE: plural */
    QF_poolInit(l_smlPoolSto, sizeof(l_smlPoolSto), sizeof(l_smlPoolSto[0]));

    for(i = 0; i < N_CLOOP; ++i) {           /* start the active objects... */
        QActive_start((QActive*)&l_cloop[i], i+1   /* lowest AO priority: 1 */
                      , l_cloopQueueSto[i], Q_DIM(l_cloopQueueSto[i])
                      , NULL/* I don't supply stack */, 1024 /* 1K of stack */
                      , NULL/* no data to supply to initial transition */);
    }

    return QF_run();                              /* run the QF application */
}