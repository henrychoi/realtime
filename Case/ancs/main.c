#include "qpn.h"
#include "qs_trace.h"
#include "appsig.h"

static QEvt l_arrayQueue[2];//Array event queue
void Array_ctor(); //and its ctor
extern struct Apa102Array l_Array;

static QEvt l_bleQueue[2];//Ble event queue
void Ble_ctor(); //and its ctor
extern struct BlePeripheral l_Ble;

/* QF_active[] array defines all active object control blocks --------------*/
QActiveCB const Q_ROM QF_active[] = {
    { (QActive *)0,           (QEvt *)0,        0U                    },
    { (QActive *)&l_Ble,      l_bleQueue,       Q_DIM(l_bleQueue)     },
    { (QActive *)&l_Array,    l_arrayQueue,     Q_DIM(l_arrayQueue)   }
};

int main(void)
{
    Ble_ctor();
    Array_ctor();

    QF_init(Q_DIM(QF_active)); /* initialize the QF-nano framework */
    void BSP_init(); BSP_init(); /* initialize the Board Support Package */

    /* dictionaries... */
    QS_USR_DICTIONARY(TRACE_SDK_EVT);
    QS_USR_DICTIONARY(TRACE_PEER_EVT);
    QS_USR_DICTIONARY(TRACE_ADV_EVT);
    QS_USR_DICTIONARY(TRACE_BLE_EVT);
    QS_USR_DICTIONARY(TRACE_DM_EVT);
    QS_USR_DICTIONARY(TRACE_ANCS_EVT);

    return QF_run(); /* run the QF application */
}
