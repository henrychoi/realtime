#ifndef QS_TRACE_H_
#define QS_TRACE_H_

#include "qs.h"

enum TraceType { /* application-specific trace records */
	TRACE_SDK_EVT = QS_USER,
	TRACE_BLE_EVT,
	TRACE_ADV_EVT,
	TRACE_CONN_EVT,
	TRACE_SEC_EVT,
	TRACE_PEER_EVT,
	TRACE_ALERT_SVC,
	TRACE_QS_CMD,
};

void BSP_setTP();
void BSP_clearTP();

#endif /* QS_TRACE_H_ */
