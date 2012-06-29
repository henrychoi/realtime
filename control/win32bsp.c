#include "qp_port.h"/* Has to be the first header to be included. */
#include "HSMCLoop.h"
#include "win32bsp.h"
#include <conio.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

Q_DEFINE_THIS_FILE

/* local variables ---------------------------------------------------------*/
static uint8_t l_running;

#ifdef Q_SPY

static SOCKET  l_sock = INVALID_SOCKET;
#endif

/*..........................................................................*/
static DWORD WINAPI idleThread(LPVOID par) {/* signature for CreateThread() */
    (void)par;
    l_running = (uint8_t)1;
    while (l_running) {
        Sleep(10);                                      /* wait for a while */
        if (_kbhit()) {                                 /* any key pressed? */
            if (_getch() == '\33') {          /* see if the ESC key pressed */
                QF_PUBLISH(Q_NEW(QEvt, TERMINATE_SIG), (void *)0);
            }
        }
#ifdef Q_SPY
        {
            uint16_t nBytes = 1024;
            uint8_t const *block;
            QF_CRIT_ENTRY(dummy);
            block = QS_getBlock(&nBytes);
            QF_CRIT_EXIT(dummy);
            if (block != (uint8_t *)0) {
                send(l_sock, (char const *)block, nBytes, 0);
            }
        }
#endif
    }
    return 0;                                             /* return success */
} 
/*..........................................................................*/
void BSP_init(int argc, char *argv[]) {
    DWORD threadId;
    HANDLE hIdle;
    char const *hostAndPort = "localhost:6601";

    if (argc > 1) {                                      /* port specified? */
        hostAndPort = argv[1];
    }
    if (!QS_INIT(hostAndPort)) {
        printf("\nUnable to open QSpy socket\n");
        exit(-1);
    }

    hIdle = CreateThread(NULL, 1024, &idleThread, (void *)0, 0, &threadId);
    Q_ASSERT(hIdle != (HANDLE)0);                 /* thread must be created */
    SetThreadPriority(hIdle, THREAD_PRIORITY_IDLE);


    QF_setTickRate(BSP_TICKS_PER_SEC);         /* set the desired tick rate */

    printf("Real-time control loop"
           "\nQEP %s\nQF  %s\n"
           "Press ESC to quit...\n",
           QEP_getVersion(),
           QF_getVersion());
}
/*..........................................................................*/
void QF_onStartup(void) {
}
/*..........................................................................*/
void QF_onCleanup(void) {
    l_running = (uint8_t)0;
}
void Q_onAssert(char const Q_ROM * const Q_ROM_VAR file, int line) {
    fprintf(stderr, "Assertion failed in %s, line %d", file, line);
    QF_stop();
    *((int*)NULL) = 0;             /* Running in VS, so invoke the debugger */
}

/*--------------------------------------------------------------------------*/
#ifdef Q_SPY                                         /* define QS callbacks */

uint8_t QS_onStartup(void const *arg) {
    static uint8_t qsBuf[2*1024];              /* 2K buffer for Quantum Spy */
    static WSADATA wsaData;
    char host[64];
    char const *src;
    char *dst;
    USHORT port = 6601;                                     /* default port */
    ULONG ioctl_opt = 1;
    struct sockaddr_in servAddr;
    struct hostent *server;

    QS_initBuf(qsBuf, sizeof(qsBuf));

    /* initialize Windows sockets */
    if (WSAStartup(MAKEWORD(2,0), &wsaData) == SOCKET_ERROR) {
        printf("Windows Sockets cannot be initialized.");
        return (uint8_t)0;
    }

    src = (char const *)arg;
    dst = host;
    while ((*src != '\0') && (*src != ':') && (dst < &host[sizeof(host)])) {
        *dst++ = *src++;
    }
    *dst = '\0';
    if (*src == ':') {
        port = (USHORT)strtoul(src + 1, NULL, 10);
    }


    l_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);       /* TCP socket */
    if (l_sock == INVALID_SOCKET){
        printf("Socket cannot be created.\n"
               "Windows socket error 0x%08X.",
               WSAGetLastError());
        return (uint8_t)0;
    }

    server = gethostbyname(host);
    if (server == NULL) {
        printf("QSpy host name cannot be resolved.\n"
               "Windows socket error 0x%08X.",
               WSAGetLastError());
        return (uint8_t)0;
    }
    memset(&servAddr, 0, sizeof(servAddr));
    servAddr.sin_family = AF_INET;
    memcpy(&servAddr.sin_addr, server->h_addr, server->h_length);
    servAddr.sin_port = htons(port);
    if (connect(l_sock, (struct sockaddr *)&servAddr, sizeof(servAddr))
        == SOCKET_ERROR)
    {
        printf("Socket cannot be connected to the QSpy server.\n"
               "Windows socket error 0x%08X.",
               WSAGetLastError());
        QS_EXIT();
        return (uint8_t)0;
    }

    /* Set the socket to non-blocking mode. */
    if (ioctlsocket(l_sock, FIONBIO, &ioctl_opt) == SOCKET_ERROR) {
        printf("Socket configuration failed.\n"
               "Windows socket error 0x%08X.",
               WSAGetLastError());
        QS_EXIT();
        return (uint8_t)0;
    }
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
//    QS_FILTER_OFF(QS_QF_ACTIVE_UNSUBSCRIBE);
    QS_FILTER_OFF(QS_QF_ACTIVE_POST_FIFO);
//    QS_FILTER_OFF(QS_QF_ACTIVE_POST_LIFO);
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
    QS_FILTER_OFF(QS_QF_TICK);
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

    return (uint8_t)1;                                           /* success */
}
/*..........................................................................*/
void QS_onCleanup(void) {
    if (l_sock != INVALID_SOCKET) {
        closesocket(l_sock);
    }
    WSACleanup();
}
/*..........................................................................*/
void QS_onFlush(void) {
    uint16_t nBytes = 1000;
    uint8_t const *block;
    QF_CRIT_ENTRY(dummy);
    while ((block = QS_getBlock(&nBytes)) != (uint8_t *)0) {
        QF_CRIT_EXIT(dummy); \
        send(l_sock, (char const *)block, nBytes, 0);
        nBytes = 1000;
        QF_CRIT_ENTRY(dummy);
    }
    QF_CRIT_EXIT(dummy);
}
/*..........................................................................*/
QSTimeCtr QS_onGetTime(void) {
    return (QSTimeCtr)clock();
}
#endif                                                             /* Q_SPY */
/*--------------------------------------------------------------------------*/
