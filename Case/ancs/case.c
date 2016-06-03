#include "app_util_platform.h"
#include <string.h>
#include "qpn.h"
#include "qs_trace.h"
#include "appsig.h"

Q_DEFINE_THIS_FILE

/* Active object class -----------------------------------------------------*/
typedef struct {
/* protected: */
    QActive super;

/* private: */
} Case;

static QState Case_selfie(Case* const me);
static QState Case_normal(Case* const me);
static QState Case_behind(Case* const me);
static QState Case_idle(Case* const me);
static QState Case_alerting(Case* const me);

static QState Case_caughtup(Case* const me) {
	switch(Q_SIG(me)) {
	case UNREAD_SIG: {

	} return Q_TRAN(&Case_behind);
	default:
		return Q_SUPER(&Case_idle);
	}
}
static QState Case_behind(Case* const me) {
	switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
	    return Q_HANDLED();

	default:
		return Q_SUPER(&Case_idle);
	}
}
static QState Case_idle(Case* const me) {
	switch(Q_SIG(me)) {
	case Q_TIMEOUT_SIG:
        //Q_ASSERT(nrf_drv_spi_transfer(&spi
        //		, me->array[me->cursor], sizeof(me->array[0]), NULL, 0)
        //		== NRF_SUCCESS);
	    return Q_HANDLED();

	case ALERT_SIG: {
		const AppEvt* pe = (const AppEvt*)Q_PAR(me);

	} return Q_TRAN(&Case_alerting);

	case DISPLAY_DONE_SIG:
		return Q_HANDLED();

	default:
		return Q_SUPER(&Case_normal);
	}
}
static QState Case_alerting(Case* const me) {
	switch(Q_SIG(me)) {
	case ALERT_SIG: {
		const AppEvt* pe = (const AppEvt*)Q_PAR(me);

	} return Q_TRAN(&Case_alerting);

	default:
		return Q_SUPER(&Case_normal);
	}
}
static QState Case_selfie(Case* const me) {
	switch(Q_SIG(me)) {
	case SELFIE_SIG:
		return Q_TRAN(&Case_normal);
	default:
		return Q_SUPER(&QHsm_top);
	}
}
