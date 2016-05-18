#ifndef dpp_h
#define dpp_h

enum DPPSignals {
    NUS_SIG = Q_USER_SIG, /* Received from the NUS server */
    MAX_PUB_SIG,    /* the last published signal */

    TIMEOUT_SIG,    /* used by Philosophers for time events */
    MAX_SIG         /* the last signal */
};

typedef struct {
/* protected: */
    QEvt super;

/* public: */
    uint8_t type;
    uint8_t param[4];
} NUSEvt;

extern QActive* const AO_Table;

enum AO_ID {
	AO_TABLE = 1
};

enum TableState {
	TABLE_STATE_ACTIVE = 0x100,
};

#define BSP_TICKS_PER_SEC 10

void BSP_displayPaused(uint8_t paused);

#endif /* dpp_h */
