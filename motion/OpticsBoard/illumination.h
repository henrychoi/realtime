#ifndef illumination_h
#define illumination_h

enum IlluminationSignals {
	ON_SIG = Q_USER_SIG
};

void Illumination_ctor(void);

extern struct IlluminationTag AO_Illumination;

#endif /* illumination_h */
