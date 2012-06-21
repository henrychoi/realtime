/*****************************************************************************
* Product: "Dining Philosophers Problem" example, QK kernel
* Last Updated for Version: 4.5.00
* Date of the Last Update:  May 18, 2012
*
*                    Q u a n t u m     L e a P s
*                    ---------------------------
*                    innovating embedded systems
*
* Copyright (C) 2002-2012 Quantum Leaps, LLC. All rights reserved.
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
#include "qp_port.h"
#include "dpp.h"
#include "bsp.h"
#include "xparameters.h"
#include "xil_cache.h"
#include "xintc.h"
#include "xgpio.h"
#include "xtmrctr.h"
#include "xuartlite.h"

Q_DEFINE_THIS_FILE

/* Local-scope objects -----------------------------------------------------*/
static uint32_t l_delay = 0UL; /* limit for the loop counter in busyDelay() */
static XIntc intc;
#define GPIO_CHANNEL 1
static XGpio led8, led5, button5;
#define MY_TIMER_ID 0
static XTmrCtr timer;
#define SystemFrequency XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ

#ifdef Q_SPY

    QSTimeCtr QS_tickTime_;
    QSTimeCtr QS_tickPeriod_;
    static uint8_t l_SysTick_Handler;
    static uint8_t l_GPIOPortA_IRQHandler = 0;

    #define UART_BAUD_RATE      9600
    #define UART_TXFIFO_DEPTH   0xFFFF
    static XUartLite uart;

    enum AppRecords {                 /* application-specific trace records */
        PHILO_STAT = QS_USER
    };

#endif

/*..........................................................................*/
void SysTick_Handler(void* p, u8 timerId) {
	(void)p; (void)timerId;
    QK_ISR_ENTRY();                       /* inform QK-nano about ISR entry */

#ifdef Q_SPY
    QS_tickTime_ += 1; //QS_tickPeriod_; /* account for the clock rollover */
#endif

    QF_TICK(&l_SysTick_Handler);           /* process all armed time events */

    QK_ISR_EXIT();                         /* inform QK-nano about ISR exit */
}
/*..........................................................................*/
void GPIOPortA_IRQHandler(void* p) {
	XIntc_Acknowledge(&intc
				  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
	XGpio_InterruptClear((XGpio*)p, GPIO_CHANNEL);

	QK_ISR_ENTRY();                      /* infrom QK about entering an ISR */

	if(l_GPIOPortA_IRQHandler) { /* If already hot, only care about unpress */
	    if(!XGpio_DiscreteRead((XGpio*)p, GPIO_CHANNEL))
	    	l_GPIOPortA_IRQHandler = 0;
	}
	else { /* If unpressed, only catch the first button press */
		l_GPIOPortA_IRQHandler = XGpio_DiscreteRead((XGpio*)p, GPIO_CHANNEL);
        QACTIVE_POST(AO_Table, Q_NEW(QEvt, MAX_PUB_SIG), /* for testing... */
                 &l_GPIOPortA_IRQHandler);
	}
    QK_ISR_EXIT();                        /* infrom QK about exiting an ISR */
}

/*..........................................................................*/
void BSP_init() {
	int status;
	Xil_ICacheEnable();
	Xil_DCacheEnable();

	status = XGpio_Initialize(&led8, XPAR_LEDS_8BITS_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
	XGpio_SetDataDirection(&led8, GPIO_CHANNEL, 0x0);//output

	status = XGpio_Initialize(&led5, XPAR_LEDS_POSITIONS_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
	XGpio_SetDataDirection(&led5, GPIO_CHANNEL, 0x0);//output

	// Q: use interrupt for URT?
	// Not necessary for now since I don't read from console

	status = XIntc_Initialize(&intc, XPAR_INTC_0_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
	microblaze_enable_interrupts();//uBlaze intr

	status = XGpio_Initialize(&button5, XPAR_PUSH_BUTTONS_5BITS_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
	// The hardware must be built for dual channels if this function is used
	// with any channel other than 1. If it is not, this function will assert.
	// After this call, I can, if I wish, poll the GPIO with
	// u32 val = XGpio_DiscreteRead(&button5, BUTTON5_CHANNEL)
	XGpio_SetDataDirection(&button5, GPIO_CHANNEL, 0xFFFFFFFF); //out: 0, in: 1

	XGpio_InterruptEnable(&button5, 0xFF);
	// Interrupts enabled through XGpio_InterruptEnable() will not be passed
	// through until the global enable bit is set by this function. This
	// function is designed to allow all interrupts to be
	// enabled easily for exiting a critical section.
	XGpio_InterruptGlobalEnable(&button5);

	status = XIntc_Connect(&intc
			  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR
			  , GPIOPortA_IRQHandler, &button5);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
	XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);

	status = XTmrCtr_Initialize(&timer, XPAR_AXI_TIMER_0_DEVICE_ID);
	XTmrCtr_SetHandler(&timer, SysTick_Handler, &timer);
	XTmrCtr_SetOptions(&timer, MY_TIMER_ID,
			XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);
	XTmrCtr_SetResetValue(&timer, MY_TIMER_ID
			//count up (default behavior) from this value
			, (~0 - SystemFrequency/BSP_TICKS_PER_SEC) + 1);
	status = XIntc_Connect(&intc
			  , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR
			  , XTmrCtr_InterruptHandler, &timer);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
	XTmrCtr_Start(&timer, MY_TIMER_ID);//can stop later with XTmrCtr_Stop()

	XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);

    if (QS_INIT((void *)0) == 0) {    /* initialize the QS software tracing */
        Q_ERROR();
    }

    QS_OBJ_DICTIONARY(&l_SysTick_Handler);
    QS_OBJ_DICTIONARY(&l_GPIOPortA_IRQHandler);
}
/*..........................................................................*/
void BSP_displyPhilStat(uint8_t n, char const *stat) {
    char str[2];
    str[0] = stat[0];
    str[1] = '\0';

    QS_BEGIN(PHILO_STAT, AO_Philo[n])  /* application-specific record begin */
        QS_U8(1, n);                                  /* Philosopher number */
        QS_STR(stat);                                 /* Philosopher status */
    QS_END()
}
/*..........................................................................*/
void BSP_driveLED(uint8_t channel, uint8_t state) {
    if (state != 0) {/* turn the User LED on  */
    	XGpio_DiscreteWrite(&led8, GPIO_CHANNEL, 1<<channel);
    }
    else {/* turn the User LED off */
    	XGpio_DiscreteClear(&led8, GPIO_CHANNEL, 1<<channel);
    }
}
/*..........................................................................*/
void BSP_busyDelay(void) {
    uint32_t volatile i = l_delay;
    while (i-- > 0UL) {                                   /* busy-wait loop */
    }
}

/*..........................................................................*/
void QF_onStartup(void) {
    int status = XIntc_Start(&intc, XIN_REAL_MODE);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
}
/*..........................................................................*/
void QF_onCleanup(void) {
}
/*..........................................................................*/
void QK_init(void) {}
/*..........................................................................*/
void QK_onIdle(void) {
#if 0
    /* toggle the User LED on and then off, see NOTE01 */
    QF_INT_DISABLE();
    BSP_driveLED(7, 1);
    BSP_driveLED(7, 0);
    QF_INT_ENABLE();
#endif
#ifdef Q_SPY
    if (!XUartLite_IsSending(&uart)) {                      /* TX done? */
        uint16_t fifo = UART_TXFIFO_DEPTH;       /* max bytes we can accept */
        uint8_t const *block;

        QF_INT_DISABLE();
        block = QS_getBlock(&fifo);    /* try to get next block to transmit */
        QF_INT_ENABLE();

        while (fifo) {                    /* any bytes in the block? */
        	uint32_t sent = XUartLite_Send(&uart, (u8*)block, fifo);
        	if(sent > 0)
        		fifo -= sent;
        }
    }
#elif defined NDEBUG
    /* Put the CPU and peripherals to the low-power mode.
    * you might need to customize the clock management for your application,
    * see the datasheet for your particular MCU.
    */
#endif
}

/*..........................................................................*/
void Q_onAssert(char const Q_ROM * const Q_ROM_VAR file, int line) {
    (void)file;                                   /* avoid compiler warning */
    (void)line;                                   /* avoid compiler warning */
    QF_INT_DISABLE();         /* make sure that all interrupts are disabled */
    XGpio_DiscreteWrite(&led5, GPIO_CHANNEL, 1<<0);//indicate death
    for (;;) {       /* NOTE: replace the loop with reset for final version */
    }
}
/*..........................................................................*/
/* error routine that is called if the CMSIS library encounters an error    */
void assert_failed(char const *file, int line) {
    Q_onAssert(file, line);
}

/*--------------------------------------------------------------------------*/
#ifdef Q_SPY
/*..........................................................................*/
uint8_t QS_onStartup(void const *arg) {
    static uint8_t qsBuf[6*256];                  /* buffer for Quantum Spy */
    QS_initBuf(qsBuf, sizeof(qsBuf));

	int status = XUartLite_Initialize(&uart, XPAR_DEBUG_MODULE_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }

    QS_tickPeriod_ = SystemFrequency / BSP_TICKS_PER_SEC + 1;
    QS_tickTime_ = 0;

                                                 /* setup the QS filters... */
    QS_FILTER_ON(QS_ALL_RECORDS);

//    QS_FILTER_OFF(QS_QEP_STATE_EMPTY);
//    QS_FILTER_OFF(QS_QEP_STATE_ENTRY);
//    QS_FILTER_OFF(QS_QEP_STATE_EXIT);
//    QS_FILTER_OFF(QS_QEP_STATE_INIT);
//    QS_FILTER_OFF(QS_QEP_INIT_TRAN);
//    QS_FILTER_OFF(QS_QEP_INTERN_TRAN);
//    QS_FILTER_OFF(QS_QEP_TRAN);
//    QS_FILTER_OFF(QS_QEP_IGNORED);

    QS_FILTER_OFF(QS_QF_ACTIVE_ADD);
    QS_FILTER_OFF(QS_QF_ACTIVE_REMOVE);
    QS_FILTER_OFF(QS_QF_ACTIVE_SUBSCRIBE);
    QS_FILTER_OFF(QS_QF_ACTIVE_UNSUBSCRIBE);
    QS_FILTER_OFF(QS_QF_ACTIVE_POST_FIFO);
    QS_FILTER_OFF(QS_QF_ACTIVE_POST_LIFO);
    QS_FILTER_OFF(QS_QF_ACTIVE_GET);
    QS_FILTER_OFF(QS_QF_ACTIVE_GET_LAST);
    QS_FILTER_OFF(QS_QF_EQUEUE_INIT);
    QS_FILTER_OFF(QS_QF_EQUEUE_POST_FIFO);
    QS_FILTER_OFF(QS_QF_EQUEUE_POST_LIFO);
    QS_FILTER_OFF(QS_QF_EQUEUE_GET);
    QS_FILTER_OFF(QS_QF_EQUEUE_GET_LAST);
    QS_FILTER_OFF(QS_QF_MPOOL_INIT);
    QS_FILTER_OFF(QS_QF_MPOOL_GET);
    QS_FILTER_OFF(QS_QF_MPOOL_PUT);
    QS_FILTER_OFF(QS_QF_PUBLISH);
    QS_FILTER_OFF(QS_QF_NEW);
    QS_FILTER_OFF(QS_QF_GC_ATTEMPT);
    QS_FILTER_OFF(QS_QF_GC);
//    QS_FILTER_OFF(QS_QF_TICK);
    QS_FILTER_OFF(QS_QF_TIMEEVT_ARM);
    QS_FILTER_OFF(QS_QF_TIMEEVT_AUTO_DISARM);
    QS_FILTER_OFF(QS_QF_TIMEEVT_DISARM_ATTEMPT);
    QS_FILTER_OFF(QS_QF_TIMEEVT_DISARM);
    QS_FILTER_OFF(QS_QF_TIMEEVT_REARM);
    QS_FILTER_OFF(QS_QF_TIMEEVT_POST);
    QS_FILTER_OFF(QS_QF_CRIT_ENTRY);
    QS_FILTER_OFF(QS_QF_CRIT_EXIT);
    QS_FILTER_OFF(QS_QF_ISR_ENTRY);
    QS_FILTER_OFF(QS_QF_ISR_EXIT);

    return (uint8_t)1;                                    /* return success */
}
/*..........................................................................*/
void QS_onCleanup(void) {
}
/*..........................................................................*/
QSTimeCtr QS_onGetTime(void) {            /* invoked with interrupts locked */
	// Consider whether finer grain time would be useful
	return QS_tickTime_;
}
/*..........................................................................*/
void QS_onFlush(void) {
    uint16_t fifo = UART_TXFIFO_DEPTH;                     /* Tx FIFO depth */
    uint8_t const *block;
    QF_INT_DISABLE();
    while ((block = QS_getBlock(&fifo)) != (uint8_t *)0) {
        QF_INT_ENABLE();
                                           /* busy-wait until TX FIFO empty */
        while (XUartLite_IsSending(&uart)) {
        }

        while (fifo--) {                    /* any bytes in the block? */
        	uint32_t sent = XUartLite_Send(&uart, (u8*)block, fifo);
        	if(sent > 0)
        		fifo -= sent;
        }
        fifo = UART_TXFIFO_DEPTH;              /* re-load the Tx FIFO depth */
        QF_INT_DISABLE();
    }
    QF_INT_ENABLE();
}
#endif                                                             /* Q_SPY */
/*--------------------------------------------------------------------------*/

/*****************************************************************************
* NOTE01:
* The User LED is used to visualize the idle loop activity. The brightness
* of the LED is proportional to the frequency of invcations of the idle loop.
* Please note that the LED is toggled with interrupts locked, so no interrupt
* execution time contributes to the brightness of the User LED.
*/
