#ifndef excitation_h
#define excitation_h

enum ExcitationSignals {
	TIMERB1_SIG = Q_USER_SIG
};

enum ExcitationColors {
	COLOR_UV
  , COLOR_BLUE
  , COLOR_CYAN
  , COLOR_TEAL
  , COLOR_GREEN
  , COLOR_YELLOW
  , COLOR_RED
};

void Excitation_init(void);

extern struct Excitation AO_excitation;

#endif /* excitation_h */
