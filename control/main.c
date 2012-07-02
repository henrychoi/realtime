#include <string.h>
#include <stdlib.h> /* for atoi */
#include <stdio.h>
#include "qp_port.h"
#include "HSMCLoop.h"
#ifdef WIN32
# include "win32bsp.h"
#elif defined(__MICROBLAZE__)
# include "bsp.h"
#endif

/* Local-scope objects -----------------------------------------------------*/
static QSubscrList l_subscrSto[MAX_PUB_SIG];         /* a list for each sig */
static union SmallEvents {
    void   *e0;                                       /* minimum event size */
    uint8_t e1[sizeof(StartEvent)];
    /* ... other event types to go into this pool */
} l_smlPoolSto[16];/* storage for the small event pool; note the queue storage
                   is just an array */
#define N_CLOOP 1
static CLoop l_cloop[N_CLOOP];                      /* CLoop active objects */
//QActive* const AO_cloop0 = (QActive*)&l_cloop0;
static QEvt const* l_cloopQueueSto[N_CLOOP][8];

/*............................................................................
 QSpy needs a dictionary of all static objects.  Dictionary uses
 preprocessor macro to generate a name, so I can't just invoke each
 instance's dictionary publish method even if it exists.
 */
void declareQSDictionary() {
    uint8_t i;

    /* dictionary available in in this file: -------------------------------*/
    QS_OBJ_DICTIONARY(l_smlPoolSto);

    QS_OBJ_DICTIONARY(&l_cloop[0]);/* All active objects in this app:       */

    QS_FUN_DICTIONARY(&QHsm_top); /* An HSM always has the top pseudo state */

                                                         /* global signals: */
    QS_SIG_DICTIONARY(START, 0);
    QS_SIG_DICTIONARY(STOP, 0);

    /* dictionary available in other files: --------------------------------*/
    CLoop_declareStaticQSDictionary(); /* The static dictionary */
    for(i = 0; i < N_CLOOP; ++i) { /* Per instance dictionary */
        CLoop_declareInstanceQSDictionary(&l_cloop[i]);
    }
}
/*..........................................................................*/
int main(
#ifdef WIN32
    int argc, char *argv[]
#endif
) {
    uint8_t i;
    for(i = 0; i < N_CLOOP; ++i) {/* Instantiate the control loop active
                                  objects; this is unnecessary in C++, as the
                                  ctor is called even for a static object */
        CLoop_ctor(&l_cloop[i]);
    }

#ifdef WIN32
    BSP_init(argc, argv);           /* initialize the Board Support Package */
#elif defined(__MICROBLAZE__)
    BSP_init();
#endif
    QF_init();     /* initialize the framework and the underlying RT kernel */
    declareQSDictionary();/* TODO: send object dictionaries on (re)connection
                           * with QSpy */
    QF_psInit(l_subscrSto, Q_DIM(l_subscrSto));   /* init publish-subscribe */
                                    /* initialize event pools; NOTE: plural */
    QF_poolInit(l_smlPoolSto, sizeof(l_smlPoolSto), sizeof(l_smlPoolSto[0]));

    for(i = 0; i < N_CLOOP; ++i) {           /* start the active objects... */
        QActive_start((QActive*)&l_cloop[i], i+1   /* lowest AO priority: 1 */
                      , l_cloopQueueSto[i], Q_DIM(l_cloopQueueSto[i])
                      , NULL/* I don't supply stack */, BSP_STACK_SIZE
                      , NULL/* no data to supply to initial transition */);
    }

    return QF_run();                              /* run the QF application */
}

/*..........................................................................*/
static const char* COMMAND_SEPARATORS = ", \t\n\r";
const char* USAGE =
"Enter signal name followed by values separated by space, comma, or tab.\n"
"End the signal with a ; (semicolon).\n"
"Signal names are case insensitive.\n"
"Example: START, 10;\n"
"Supported signals:\n"
"\tSTART <# BSP ticks per sample loop tick (max: 255)>;\n"
"\tSTOP;\n";
const char* PROMPT = "$ ";

uint8_t onCommandline(char* line) {
    char *next_token
        , *token= strtok_r(line, COMMAND_SEPARATORS, &next_token);
    if(!token) {
        return 0;
    } else {
#ifdef SANITY_TEST
        for(; token; token = strtok_r(NULL, COMMAND_SEPARATORS, &next_token))
            printf("%s\n", token);
#endif//SANITY_TEST
        int i; for(i = 0; token[i]; i++) token[i] = toupper(token[i]);
        /* The following section has to keep up with number of signals */
        if(strcmp(token, "START") == 0) {
            token = strtok_r(NULL, COMMAND_SEPARATORS, &next_token);
            if(!token) {
                return 0;
            } else {
                uint8_t period_in_tick = atoi(token);
                StartEvent* e = Q_NEW(StartEvent, START);
                e->period_in_tick = period_in_tick; 
                QF_PUBLISH((QEvt*)e, NULL /* TODO: declare sender as BSP */);
            }
        } else if(strcmp(token, "STOP") == 0) {
            QF_PUBLISH(Q_NEW(QEvt, STOP), NULL);
        } else {
            return 0;
        }
    }
    return 1;
}

char* strchrn(const char* s, char c, uint16_t maxl) {
	uint16_t l = maxl;
	if(!s) return NULL;
    for(l = 0; *s && (*s != c) && l < maxl; ++s, ++l);
	return /* found it? */ (*s == c) ? (char*)s : NULL;
}

void onPacket(char* payload, uint16_t len
    , BSPConsoleReplyFn replyFn, void* replyParam) {
#   define COMMAND_BUFFER_SIZE 256
	static char commandBuffer[COMMAND_BUFFER_SIZE];
	static char* bufferPtr = commandBuffer;
#   define REPLY_BUFFER_SIZE 1024
	char reply[REPLY_BUFFER_SIZE];

    if((bufferPtr + len) >= (commandBuffer + COMMAND_BUFFER_SIZE)) {
		/* Too big; can't handle it */
		sprintf(reply, "Command length > maximum allowed %d\n"
				, COMMAND_BUFFER_SIZE);
        replyFn(reply, REPLY_BUFFER_SIZE, replyParam);
	} else { /* Buffer away the command */
    	char* found = strchrn(payload, ';', len);
		if(!found) { /* Command continues in later packet */
			strncpy(bufferPtr, payload, len);
			bufferPtr += len;
		} else {
            /* Command end received; form a whole command WITHOUT
                command end; Continue from last partial string */
			strncpy(bufferPtr, payload, found - payload);

            /* Terminating NULL at the end of the complete command */
            commandBuffer[(bufferPtr-commandBuffer) + (found-payload)] = 0;

            sprintf(reply, "Received signal: %s\n", commandBuffer);
            replyFn(reply, REPLY_BUFFER_SIZE, replyParam);

            if(!onCommandline(commandBuffer)) {
            	sprintf(reply, "Invalid signal.\n%s", USAGE);
                replyFn(reply, REPLY_BUFFER_SIZE, replyParam);
            }
            replyFn(PROMPT, REPLY_BUFFER_SIZE, replyParam);

			bufferPtr = commandBuffer;   /* Restore the temp pointer to head */
			
			if(len > (++found - payload)) { /* Copy remainder */
                uint16_t remain;
                remain = len - (found - payload);
                strncpy(bufferPtr, found, remain);
                bufferPtr += remain;
            }
		}
    }
}
