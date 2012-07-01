// 3rd party stuff ////////////////////////////////////////
#include "gtest/gtest.h"
#include "qep_port.h"

uint16_t strlenn(const char* s, uint16_t maxl) {
	uint16_t l = 0;
	if(s)
        for(; *s && l < maxl; ++s, ++l);
	return l;
}

char* strchrn(const char* s, char c, uint16_t maxl) {
	uint16_t l = maxl;
	if(!s) return NULL;
    for(l = 0; *s && (*s != c) && l < maxl; ++s, ++l);
	return /* found it? */ (*s == c) ? (char*)s : NULL;
}

char* strtok_r(char *s, const char *delim, char **last) {
    char *spanp;
    int c, sc;
    char *tok;

    if (s == NULL && (s = *last) == NULL) return NULL;

    /* Skip (span) leading delimiters (s += strspn(s, delim), sort of). */
cont:
    c = *s++;
    for (spanp = (char *)delim; (sc = *spanp++) != 0; ) {
    	if (c == sc) goto cont;
    }

    if (c == 0) { /* no non-delimiter characters */
		*last = NULL;
		return NULL;
    }
    tok = s - 1;

    /* Scan token (scan for delimiters: s += strcspn(s, delim), sort of).
     * Note that delim must have one NUL; we stop if we see that, too. */
    for (;;) {
		c = *s++;
		spanp = (char *)delim;
		do {
			if ((sc = *spanp++) == c) {
				if (c == 0) s = NULL;
				else {
					char *w = s - 1;
					*w = '\0';
				}
				*last = s;
				return tok;
			}
		}
		while (sc != 0);
    }
    /* NOTREACHED */
}
static const char* COMMAND_SEPARATORS = ", \t\n\r";
struct FakeTcpPacket {
    char* payload;
    uint16_t len;
};

// Wrapper layer to emulate uBlaze programming
#ifdef WIN32
# define MIN(a,b) (a) < (b) ? (a) : (b)
# define tcp_write(tpcb, reply, replyLen, f) _write(1, reply, replyLen)
# define ERR_OK 0
# define pbuf_free(p) (p)
# define sprintf sprintf_s
# define tcp_sndbuf(tpcb) (9*1024)
#endif

int onMessage(struct FakeTcpPacket* p) {
    int err;
#define COMMAND_BUFFER_SIZE 1024
	static char commndBuffer[COMMAND_BUFFER_SIZE];
	static char* bufferPtr = commndBuffer;
	char* eol;
#define REPLY_BUFFER_SIZE 1024
	char reply[1024];
	uint16_t replyLen;

	if((bufferPtr + p->len) >= (commndBuffer + COMMAND_BUFFER_SIZE)) {
		                                       /* Too big; can't handle it */
		sprintf(reply, "Command length > maximum allowed %d\n"
				, COMMAND_BUFFER_SIZE);
		replyLen = strlenn(reply, REPLY_BUFFER_SIZE);
		replyLen = MIN(replyLen, tcp_sndbuf(tpcb));
		err = tcp_write(tpcb, reply, replyLen, TCP_WRITE_FLAG_COPY);
	} else { /* Buffer away the command */
		eol = strchrn(p->payload, 0, p->len);/* Find string terminating NULL*/
		if(!eol) {                     /* Command continues in later packet */
			memcpy(bufferPtr, p->payload, p->len);
			bufferPtr += p->len;
		} else {/* End of line received; form a whole command and handle it */
			uint16_t l;
			++eol; /* copy the terminating NULL too */
			l = eol - (char*)p->payload;
			memcpy(bufferPtr, p->payload, l); /* Copy up to and including 0 */


			bufferPtr = commndBuffer;   /* Restore the temp pointer to head */
			
			if(l < p->len) /* Copy remainder */
				memcpy(bufferPtr, eol, (p->len - l));
		}
	}

	pbuf_free(p);/* free the received pbuf */
	return ERR_OK;
}

// specific to this test /////////////////////////////////////////////
const char* TEST_STRING
    = "Hello,I love you.  Won't\t\tyou tell me your name\n\r";
TEST(CLib, strlenn) {
    EXPECT_EQ(strlenn(TEST_STRING, 100), strlen(TEST_STRING));
    EXPECT_EQ(strlenn(TEST_STRING, 10), 10);
}

TEST(CLib, strchrn) {
    char* p;
    EXPECT_FALSE(strchrn(TEST_STRING, ';', 100));
    EXPECT_FALSE(strchrn(TEST_STRING, ';', 10));

    p = strchrn(TEST_STRING, ',', 100);
    EXPECT_EQ(*p, ',');

    EXPECT_FALSE(strchrn(TEST_STRING, '\r', 20));

    p = strchrn(TEST_STRING, '\t', 100);
    EXPECT_EQ(*p, '\t');
    ++p; // The next char should also be a \t in the TEST_STRING
    EXPECT_EQ(*p, '\t');

    p = strchrn(TEST_STRING, '\r', 100);
    EXPECT_EQ(*p, '\r');
}

TEST(CLib, strtok_r) {
    char s[80];
    strncpy(s, TEST_STRING, sizeof(s));
    char *next_token
        , *token= strtok_r(s, COMMAND_SEPARATORS, &next_token);
    EXPECT_STREQ(token, "Hello");
}

TEST(CommandProcessor, streamed) {
}

int main(int argc, char* argv[]) {
    ::testing::InitGoogleTest(&argc, argv);
    int ok = RUN_ALL_TESTS();
    printf("Press <Enter> to exit");
    char temp = getchar();
}
