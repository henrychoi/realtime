//////////////////////////////////////////////////////////////////////////////
// Product:  QF/C++, ARM-Cortex, QK port, GNU compiler
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
#ifndef qf_port_h
#define qf_port_h
        // The maximum number of active objects in the application, see NOTE01
#define QF_MAX_ACTIVE               16//32
                       // The maximum number of event pools in the application
#define QF_MAX_EPOOL                6
                                                // QF interrupt disable/enable
#include "mb_interface.h"
#define QF_INT_DISABLE()            microblaze_disable_interrupts()
#define QF_INT_ENABLE()             microblaze_enable_interrupts()

                                             // QF critical section entry/exit
// QF_CRIT_STAT_TYPE not defined: "unconditional interrupt unlocking" policy
#define QF_CRIT_ENTRY(dummy)        microblaze_disable_interrupts()
#define QF_CRIT_EXIT(dummy)         microblaze_enable_interrupts()

#include "qep_port.h"                                              // QEP port
#include "qk_port.h"                   // QK port provides integration with QF
#include "qf.h"                    // QF platform-independent public interface

//////////////////////////////////////////////////////////////////////////////
// NOTE01:
// The maximum number of active objects QF_MAX_ACTIVE can be increased
// up to 63, if necessary. Here it is set to a lower level to save some RAM.
//

#endif                                                            // qf_port_h
