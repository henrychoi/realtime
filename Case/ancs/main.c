#include "qpn.h"
#include "qs_trace.h"
#include "appsig.h"

static QEvt l_arrayQueue[2];
//extern QActive * const AO_Array; //opaque handle to the Array AO
extern void Array_ctor(); //and its ctor
extern struct ArrayTag l_Array;
/* QF_active[] array defines all active object control blocks --------------*/
QActiveCB const Q_ROM QF_active[] = {
    { (QActive *)0,           (QEvt *)0,        0U                      },
    { (QActive *)&l_Array,    l_arrayQueue,     Q_DIM(l_arrayQueue)     }
};

int main(void)
{
#if 0
    bool erase_bonds;

    // Initialize.
    void timers_init(); timers_init();
    void nrf_log_init(); nrf_log_init();
    void buttons_leds_init(bool*); buttons_leds_init(&erase_bonds);
    void ble_stack_init(); ble_stack_init();
    void device_manager_init(); device_manager_init(erase_bonds);
    void db_discovery_init(); db_discovery_init();
    void scheduler_init(); scheduler_init();
    void gap_params_init(); gap_params_init();
    void service_init(); service_init();
    void advertising_init(); advertising_init();
    void conn_params_init(); conn_params_init();
#endif

    Array_ctor();

    QF_init(Q_DIM(QF_active)); /* initialize the QF-nano framework */
    void BSP_init(); BSP_init(); /* initialize the Board Support Package */

    /* object dictionaries... */
    QS_USR_DICTIONARY(TRACE_SDK_EVT);
    QS_USR_DICTIONARY(TRACE_PEER_EVT);
    QS_USR_DICTIONARY(TRACE_ADV_EVT);
    QS_USR_DICTIONARY(TRACE_BLE_EVT);
    QS_USR_DICTIONARY(TRACE_CONN_EVT);
    QS_USR_DICTIONARY(TRACE_ALERT_SVC);

#if 0
    void advertising_start(); advertising_start();
#endif

    return QF_run(); /* run the QF application */
}
