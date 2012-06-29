#include "qp_port.h"
#include "HSMCLoop.h"
#ifdef WIN32
# include "win32bsp.h"
#endif

/* Local-scope objects -----------------------------------------------------*/
static QSubscrList l_subscrSto[MAX_PUB_SIG];         /* a list for each sig */
static void *l_smlPoolSto[8];           /* storage for the small event pool */

int main(
#ifdef WIN32
    int argc, char *argv[]
#endif
) {
#ifdef WIN32
    BSP_init(argc, argv);           /* initialize the Board Support Package */
#elif defined(__MICROBLAZE__)
    BSP_init();
#endif
    QF_init();     /* initialize the framework and the underlying RT kernel */
    QF_psInit(l_subscrSto, Q_DIM(l_subscrSto));   /* init publish-subscribe */
                                    /* initialize event pools; NOTE: plural */
    QF_poolInit(l_smlPoolSto, sizeof(l_smlPoolSto), sizeof(l_smlPoolSto[0]));

    return QF_run();                              /* run the QF application */
}