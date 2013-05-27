#ifndef traj_h
#define traj_h
enum TrajSignals {
    GO_SIG = Q_USER_SIG
  , STOP_SIG
};

//Normally, I hide the implementation; but because I arrange the traj gen
//active objects as an array in this application, I am forced to expose the
//struct detail
typedef struct TrajTag {
/* protected: */
    QActive super;

/* private: */
    uint8_t id;
    float jmax;
} Traj;

void Traj_init(void);

#define N_TRAJ 1
extern struct TrajTag AO_traj[N_TRAJ];

#endif /* traj_h */
