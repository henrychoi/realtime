#ifndef traj_h
#define traj_h
#include "qpn_port.h" //To pick up N_TRAJ

enum TrajSignals {
    GO_SIG = Q_USER_SIG
  , STOP_SIG
  , GOSTOP_SIG//temporary, until I have the msg handler
};

//Normally, I hide the implementation; but because I arrange the traj gen
//active objects as an array in this application, I am forced to expose the
//struct detail
typedef struct TrajTag {
/* protected: */
    QActive super;//must be the first element of the struct for inheritance

/* private: */
    uint8_t id, direction;
    uint32_t tickInState//strictly monotonically increasing, within a state
           , step//Where I am
           , Dstep; //Where I want to get to at the end of the move
    float32 dP//Where I want to be right now
    	  , t//FP time within a state
    	  , Jmax, Smax, Amax, DP, Amax_d2, Jmax_d6
    	  , T0, T1, T3, T01, T02//, T03, T04, T05, T06
    	  , T0P2T1, T0xT0_d3, T0xT0_d3_P_T01xT1
    	  , Amax_d2xT02xT01, Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
    	  , Smax_Amax_d2_xT0P2T1, Amax_d2xT0x5T0_d3_P2T1_PSmax_xT3PT01;
// public:
} Traj;

void Traj_init(void);

extern Traj AO_traj[N_TRAJ];

#endif /* traj_h */
