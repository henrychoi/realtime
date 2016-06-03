#ifndef appsig_h
#define appsig_h

enum AppSignals {
	BLE_SIG = Q_USER_SIG, /* Received from the alert service */
    ANCS_SIG,
	SELFIE_SIG,
	//DISPLAY_DONE_SIG,
    //MAX_PUB_SIG,    /* the last published signal */

    //SYSTICK_SIG,    /* used by tick event for time events */
    MAX_SIG         /* the last signal */
};

typedef struct {
/* protected: */
    QEvt super;

/* public: */
    uint8_t param[4];
} AppEvt;

#endif /* appsig_h */
