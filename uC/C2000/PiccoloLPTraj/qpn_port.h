/*****************************************************************************
* Product: PELICAN crossing example, for TMS320C2802x
* Last Updated for Version: 4.5.03
* Date of the Last Update:  Jan 18, 2013
*
*                    Q u a n t u m     L e a P s
*                    ---------------------------
*                    innovating embedded systems
*
* Copyright (C) 2002-2013 Quantum Leaps, LLC. All rights reserved.
*
* This program is open source software: you can redistribute it and/or
* modify it under the terms of the GNU General Public License as published
* by the Free Software Foundation, either version 2 of the License, or
* (at your option) any later version.
*
* Alternatively, this program may be distributed and modified under the
* terms of Quantum Leaps commercial licenses, which expressly supersede
* the GNU General Public License and are specifically designed for
* licensees interested in retaining the proprietary status of their code.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program. If not, see <http://www.gnu.org/licenses/>.
*
* Contact information:
* Quantum Leaps Web sites: http://www.quantum-leaps.com
*                          http://www.state-machine.com
* e-mail:                  info@quantum-leaps.com
*****************************************************************************/
#ifndef qpn_port_h
#define qpn_port_h

#define Q_NFSM//Undefine if using FSM instead of HSM
//Actually need jmax, amax, smax, DP, so 4 byte is not enough
#define Q_PARAM_SIZE 0//2
#define QF_TIMEEVT_CTR_SIZE     2

/* maximum # active objects--must match EXACTLY the QF_active[] definition  */
#define QF_MAX_ACTIVE 1

                                 /* interrupt locking policy for task level */
#define QF_INT_DISABLE()        __disable_interrupts()
#define QF_INT_ENABLE()         __enable_interrupts()

                            /* interrupt locking policy for interrupt level */
/* #define QF_ISR_NEST */        /* nesting of ISRs NOT allowed, see NOTE01 */

/* Exact-width types. WG14/N843 C99 Standard, Section 7.18.1.1 */
typedef signed   char  int8_t;                                /* see NOTE02 */
typedef signed   int   int16_t;
typedef signed   long  int32_t;
typedef unsigned char  uint8_t;                               /* see NOTE02 */
typedef unsigned int   uint16_t;
typedef unsigned long  uint32_t;
#define TRUE 1
#define FALSE 0

#include "qepn.h"              /* QEP-nano platform-independent header file */
#include "qfn.h"                /* QF-nano platform-independent header file */

#undef QActive_ctor                                           /* see NOTE03 */
void QActive_ctor(QActive *me, QStateHandler initial);

/*****************************************************************************
* NOTE01:
* The TMS320C28x automatically disables interrupts upon the entry to an ISR
* by setting the INTM mask. This means, that interrupts will never nest unless
* interrupts are explicitly unlocked in the body of the ISR. QP-nano port
* assumes NO interrupt nesting, which means that interrupts are never
* re-enabled in the body of an ISR.
*
* NOTE02:
* The TMS320C28x cannot separately address 8-bit bytes (the smallest
* separately-addressable entity is a 16-bit word). Therefore the TMS320C28x
* char is 16 bits (to make it separately addressable). This yields results
* you may not expect; for example, sizeof(uint16_t) == 1 (not 2).
* To access data in increments of 8 bits, use the __byte() and __mov_byte()
* intrinsics described in "TMS320C28x Optimizing C/C++ Compiler User's Guide"
* Section 7.4.4.
*
* NOTE03:
* The standard startup code (c_int00) does NOT clear the uninitialized
* variables to zero, as required by the C-standard. The active object
* constructor performs the initialization and clearing the active object's
* data members that QF-nano assumes to start at zero.
*/

#endif                                                        /* qpn_port_h */
