#ifndef traj_h
#define traj_h
#include "qpn_port.h" //To pick up N_TRAJ

enum TrajSignals {
    GO_SIG = Q_USER_SIG
  , STOP_SIG
};

void Traj_init(void);

extern struct TrajTag AO_traj;

#endif /* traj_h */
