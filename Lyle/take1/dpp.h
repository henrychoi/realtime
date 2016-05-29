#ifndef dpp_h
#define dpp_h

enum DPPSignals {
    NUS_SIG = Q_USER_SIG, /* Received from the NUS server */
	DISPLAY_DONE_SIG,
    MAX_PUB_SIG,    /* the last published signal */

    SYSTICK_SIG,    /* used by tick event for time events */
    MAX_SIG         /* the last signal */
};

typedef struct {
/* protected: */
    QEvt super;

/* public: */
    uint8_t type;
    uint8_t param[4];
} AppEvt;

extern QActive* const AO_Panel;

enum AO_ID {
	AO_ARRAY = 1
};

enum PanelState {
	PANEL_STATE_ACTIVE = 0x100,
};

#define BSP_TICKS_PER_SEC 10

void BSP_displayPaused(uint8_t paused);

#endif /* dpp_h */
