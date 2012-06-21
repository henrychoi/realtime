//////////////////////////////////////////////////////////////////////////////
// Product: QP/C++  port to uBlaze mb toolchain
// Last Updated for Version: 4.4.00
// Date of the Last Update:  Apr 19, 2012
//
//                    Q u a n t u m     L e a P s
//                    ---------------------------
//                    innovating embedded systems
//
// Copyright (C) 2002-2012 Quantum Leaps, LLC. All rights reserved.
//
// This program is open source software: you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 2 of the License, or
// (at your option) any later version.
//
// Alternatively, this program may be distributed and modified under the
// terms of Quantum Leaps commercial licenses, which expressly supersede
// the GNU General Public License and are specifically designed for
// licensees interested in retaining the proprietary status of their code.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//
// Contact information:
// Quantum Leaps Web sites: http://www.quantum-leaps.com
//                          http://www.state-machine.com
// e-mail:                  info@quantum-leaps.com
//////////////////////////////////////////////////////////////////////////////
#ifndef qep_port_h
#define qep_port_h

                                   // use the QP namespace for all QP elements
#define Q_USE_NAMESPACE   1
// Currently, I run the code from 512 MB external RAM, so no need for this
// But might be important when I run the code from ROM
//#define Q_ROM __code
//#define Q_ROM_VAR far
#define Q_SIGNAL_SIZE 1

#include <stdint.h>  // exact-width integers, WG14/N843 C99 Standard, 7.18.1.1
#include "qep.h"                  // QEP platform-independent public interface

//typedef signed   char  int8_t;
//typedef signed   short int16_t
//typedef signed   long  int32_t;
//typedef unsigned char  uint8_t;
//typedef unsigned short uint16_t;
//typedef unsigned long  uint32_t;
#endif                                                           // qep_port_h
