/*****************************************************************************
* Product: "Dining Philosophers Problem" example
* Last Updated for Version: 4.1.03
* Date of the Last Update:  Feb 19, 2010
*
*                    Q u a n t u m     L e a P s
*                    ---------------------------
*                    innovating embedded systems
*
* Copyright (C) 2002-2010 Quantum Leaps, LLC. All rights reserved.
*
* This software may be distributed and modified under the terms of the GNU
* General Public License version 2 (GPL) as published by the Free Software
* Foundation and appearing in the file GPL.TXT included in the packaging of
* this file. Please note that GPL Section 2[b] requires that all works based
* on this software must also be made publicly available under the terms of
* the GPL ("Copyleft").
*
* Alternatively, this software may be distributed and modified under the
* terms of Quantum Leaps commercial licenses, which expressly supersede
* the GPL and are specifically designed for licensees interested in
* retaining the proprietary status of their code.
*
* Contact information:
* Quantum Leaps Web site:  http://www.quantum-leaps.com
* e-mail:                  info@quantum-leaps.com
*****************************************************************************/
#ifndef bsp_h
#define bsp_h

#define BSP_STACK_SIZE 0 /* Don't use stack? */
#define BSP_TICKS_PER_SEC 1 //1000

void BSP_init();
void BSP_driveLED(uint8_t channel, uint8_t state);

/* TODO: move to port.c */
uint16_t strlenn(const char* s, uint16_t maxl);
char* strtok_r(char *s, const char *delim, char **last);
//int8_t strcmp(const char* s1, const char* s2);
//int32_t atoi(const char* s);
#define toupper(c_) ((c_) >= 'a' && (c_) <= 'z') ? (c_) - ('a' - 'A') : (c_)

typedef void (*BSPConsoleReplyFn)(const char* msg, uint16_t msgBufferLen
		, void* param);

#endif                                                             /* bsp_h */
