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
#include "function_port.h"
#include "dpp.h"
#include "bsp.h"
#include "xparameters.h"
#include "xil_cache.h"
#include "xintc.h"
#include "xgpio.h"
#include "xtmrctr.h"
#ifdef XPAR_RS232_UART_1_DEVICE_ID//defined in xparameters.h
# include "xuartlite.h"
  static XGpio button5;
#endif
#ifdef XPAR_ETHERNET_LITE_BASEADDR//defined in xparameters.h
# include "netif/xadapter.h"
# include "lwip/init.h"
# include "lwip/tcp.h"
# include "lwip/tcp_impl.h"
  struct netif netif;
#endif

Q_DEFINE_THIS_FILE

/* Local-scope objects -----------------------------------------------------*/
static uint32_t l_delay = 0UL; /* limit for the loop counter in busyDelay() */
XIntc intc;
#define GPIO_CHANNEL 1
static XGpio led8, led5;

#define MY_TIMER_ID 0
static XTmrCtr timer;
#define SystemFrequency XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ

uint32_t l_tick = 0;

#ifdef Q_SPY
    QSTimeCtr QS_tickTime_;
    QSTimeCtr QS_tickPeriod_;
    static uint8_t l_SysTick_Handler;
    static uint8_t l_GPIOPortA_IRQHandler = 0;
# ifdef XPAR_RS232_UART_1_DEVICE_ID
    #define UART_BAUD_RATE      9600
    #define UART_TXFIFO_DEPTH   16
    static XUartLite uart;
# endif

    enum AppRecords {                 /* application-specific trace records */
        PHILO_STAT = QS_USER
    };
#endif

/*..........................................................................*/
#ifdef XPAR_ETHERNET_LITE_BASEADDR//defined in xparameters.h
# define TCP_FAST_TICKS_PER_SEC 4
# define TCP_SLOW_TICKS_PER_SEC 2
#endif//XPAR_ETHERNET_LITE_BASEADDR

void SysTick_Handler(void* p, u8 timerId) {
	(void)p; (void)timerId;
	/* From lwIP lib manual: To maintain TCP timers, lwIP requires that
	 * certain functions are called at periodic intervals by the application
	 */
	++l_tick;
#ifdef XPAR_ETHERNET_LITE_BASEADDR//defined in xparameters.h
	tcp_fasttmr();//required: call every 250 ms
	if(l_tick & 0x1) {
		XGpio_DiscreteWrite(&led5, GPIO_CHANNEL, 1<<0);
		tcp_slowtmr();//required: call every 500 ms
	} else {
		XGpio_DiscreteClear(&led5, GPIO_CHANNEL, 1<<0);
	}
#endif//XPAR_ETHERNET_LITE_BASEADDR
	XIntc_Disable(&intc//prevent infinite loop when I enable the interrupt
		  , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
    QK_ISR_ENTRY();                       /* inform QK-nano about ISR entry */

#ifdef Q_SPY
    QS_tickTime_ = l_tick;//QS_tickPeriod_;/* account for the clock rollover */
#endif

    QF_TICK(&l_SysTick_Handler);           /* process all armed time events */

    QK_ISR_EXIT();                         /* inform QK-nano about ISR exit */
    XIntc_Enable(&intc//enable the timer interrupt again
  		  , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
}
/*..........................................................................*/
#ifdef XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR
void GPIOPortA_IRQHandler(void* p) {
	XGpio_InterruptClear((XGpio*)p, GPIO_CHANNEL);
	XIntc_Disable(&intc//prevent infinite loop when I enable the interrupt
		  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);

	QK_ISR_ENTRY();                      /* infrom QK about entering an ISR */
	l_GPIOPortA_IRQHandler = XGpio_DiscreteRead((XGpio*)p, GPIO_CHANNEL);
	switch(l_GPIOPortA_IRQHandler) {
	case 0x1: /* the center button */
		QF_PUBLISH(Q_NEW(QEvt, TERMINATE_SIG), (void *)0);
		break;
	case 0x2:
	case 0x4:
	case 0x8:
	case 0x10:
        QACTIVE_POST(AO_Table, Q_NEW(QEvt, MAX_PUB_SIG), /* for testing... */
                 &l_GPIOPortA_IRQHandler);
	}
    QK_ISR_EXIT();                        /* infrom QK about exiting an ISR */

    XIntc_Enable(&intc/*enable the button interrupt again*/
	  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
}
#endif//XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR

#ifdef XPAR_ETHERNET_LITE_BASEADDR
/*..........................................................................*/
err_t echo_onrecv(void *arg, struct tcp_pcb *tpcb, struct pbuf *p
		, err_t err) {
	if (!p) {/* do not read the packet if we are not in ESTABLISHED state */
		tcp_close(tpcb);
		tcp_recv(tpcb, NULL);
		return ERR_OK;
	}
	tcp_recved(tpcb, p->len);/* packet has been received */
	/* echo back the payload */
	err = tcp_write(tpcb, p->payload, MIN(p->len, tcp_sndbuf(tpcb)), 1);
	pbuf_free(p);/* free the received pbuf */
	return ERR_OK;
}
/*..........................................................................*/
err_t echo_onaccept(void *arg, struct tcp_pcb *newpcb, err_t err) {
	static int connection = 1;

	//xil_printf("Connection (%d) Accepted\n\r", connection);

	/* set the receive callback for this connection */
	tcp_recv(newpcb, echo_onrecv);

	/* just use an integer number indicating the connection id as the
	   callback argument */
	tcp_arg(newpcb, (void*)connection);

	/* increment for subsequent accepted connections */
	connection++;

	return ERR_OK;
}
#endif//XPAR_ETHERNET_LITE_BASEADDR
/*..........................................................................*/
void BSP_init() {
	int status;
	Xil_ICacheEnable();
	Xil_DCacheEnable();

	status = XIntc_Initialize(&intc, XPAR_INTC_0_DEVICE_ID);
	if(status != XST_SUCCESS) {
		Q_ERROR();
	}

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

#ifdef XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR
	status = XGpio_Initialize(&button5, XPAR_PUSH_BUTTONS_5BITS_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
	// The hardware must be built for dual channels if this function is used
	// with any channel other than 1. If it is not, this function will assert.
	// After this call, I can, if I wish, poll the GPIO with
	// u32 val = XGpio_DiscreteRead(&button5, BUTTON5_CHANNEL)
	XGpio_SetDataDirection(&button5, GPIO_CHANNEL, ~0); //out: 0, in: 1
#endif//XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR

#ifdef XPAR_RS232_UART_1_DEVICE_ID
	status = XUartLite_Initialize(&uart, XPAR_RS232_UART_1_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
#endif

#ifdef XPAR_ETHERNET_LITE_BASEADDR
	{
		struct ip_addr ipaddr, netmask, gw;
		/* the mac address of the board. this should be unique per board */
		unsigned char mac_ethernet_address[] =
			{0x00, 0x0a, 0x35, 0x00, 0x01, 0x02};
		struct tcp_pcb *pcb;
		err_t err;

		IP4_ADDR(&ipaddr,  192, 168,   0, 254);
		IP4_ADDR(&netmask, 255, 255, 255,  0);
		IP4_ADDR(&gw,      192, 168,   0,  1);
	  	/* Add network interface to the netif_list, and set it as default */
		lwip_init();
		if(!xemac_add(&netif, &ipaddr, &netmask, &gw, mac_ethernet_address
				, XPAR_ETHERNET_LITE_BASEADDR)) {
	        Q_ERROR();
		}

		netif_set_default(&netif);
		netif_set_up(&netif);/* specify that the network if is up */

		pcb = tcp_new();/* create new TCP PCB structure */
		if (!pcb) {
	        Q_ERROR();
		}

		err = tcp_bind(pcb, IP_ADDR_ANY, 7);//the standard echo port
		if (err != ERR_OK) {
	        Q_ERROR();
		}

		/* we do not need any arguments to callback functions */
		tcp_arg(pcb, NULL);

		/* listen for connections */
		pcb = tcp_listen(pcb);
		if (!pcb) {
	        Q_ERROR();
		}

		/* specify callback to use for incoming connections */
		tcp_accept(pcb, echo_onaccept);
	}
#endif//XPAR_ETHERNET_LITE_BASEADDR

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
	int status;
#ifdef XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR
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
	XIntc_Enable(&intc
			, XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
#endif//#ifdef XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR

	status = XTmrCtr_Initialize(&timer, XPAR_AXI_TIMER_0_DEVICE_ID);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
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
#ifdef XPAR_ETHERNET_LITE_BASEADDR
	// Interrupt controller is registered with xintc inside xemac_add above
	XIntc_Enable(&intc, XPAR_INTC_0_EMACLITE_0_VEC_ID);
#endif//XPAR_ETHERNET_LITE_BASEADDR

    status = XIntc_Start(&intc, XIN_REAL_MODE);
    if(status != XST_SUCCESS) {
        Q_ERROR();
    }
    microblaze_enable_interrupts();

}
/*..........................................................................*/
void QF_onCleanup(void) {
}
/*..........................................................................*/
void QK_init(void) {}
/*..........................................................................*/
void QK_onIdle(void) {
    /* toggle the User LED on and then off, see NOTE01 */
    /* FIXME: This causes the center LED to flicker weirdly
    QF_INT_DISABLE();
	XGpio_DiscreteWrite(&led5, GPIO_CHANNEL, 1<<1);
	XGpio_DiscreteClear(&led5, GPIO_CHANNEL, 1<<1);
    QF_INT_ENABLE();
    */
#ifdef XPAR_ETHERNET_LITE_BASEADDR
	xemacif_input(&netif);
#endif//XPAR_ETHERNET_LITE_BASEADDR

#ifdef Q_SPY
	//XGpio_DiscreteWrite(&led5, GPIO_CHANNEL, 1<<2);

# ifdef XPAR_RS232_UART_1_DEVICE_ID
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
# endif

	//XGpio_DiscreteClear(&led5, GPIO_CHANNEL, 1<<2);
#elif defined NDEBUG
    /* Put the CPU and peripherals to the low-power mode.
    * you might need to customize the clock management for your application,
    * see the datasheet for your particular MCU.
    */
#endif
}

/*..........................................................................*/
void Q_onAssert(char const Q_ROM * const Q_ROM_VAR file, int line) {
    QF_INT_DISABLE();         /* make sure that all interrupts are disabled */
    XGpio_DiscreteWrite(&led5, GPIO_CHANNEL, 1<<0);//indicate death
	Xil_Assert(file, line);
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
    int status;

#ifdef XPAR_EMACLITE_0_DEVICE_ID
#endif

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
    uint8_t const *block;
    QF_INT_DISABLE();

#ifdef XPAR_RS232_UART_1_DEVICE_ID
    uint16_t fifo = UART_TXFIFO_DEPTH;                     /* Tx FIFO depth */
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
#elif defined(XPAR_INTC_0_EMACLITE_0_VEC_ID)
#else
#  error "No way to flush QS buffer"
#endif

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
