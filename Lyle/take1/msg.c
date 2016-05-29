#include "qf_port.h"      /* MSG port */
#include "msg.h"
#include "msg_pkg.h"
#include "qassert.h"      /* QP embedded systems-friendly assertions */
#include "qs.h"
#include "trace.h"
#include "dpp.h" // for NUSEvt

Q_DEFINE_THIS_MODULE("msg")

#define MSG_PTR_AT_(base_, i_) (base_[i_])

/****************************************************************************/
/****************************************************************************/
/* MSG private data (the transmit channel) */
/*! Private MSG data to keep track of the trace buffer. */
typedef struct {
    uint8_t *buf;         /*!< pointer to the start of the ring buffer */
    uint_fast16_t end;    /*!< offset of the end of the ring buffer */
    uint_fast16_t head;   /*!< offset to where next byte will be inserted */
    uint_fast16_t tail;   /*!< offset of where next byte will be extracted */
    uint_fast16_t used;   /*!< number of bytes currently in the ring buffer */
    uint8_t  seq;         /*!< the record sequence number */
    uint8_t  chksum;      /*!< the checksum of the current record */

    uint_fast8_t critNest; /*!< critical section nesting level */
} MSGPriv;

MSGPriv MSG_priv_;  /* MSG private data */

/****************************************************************************/
/**
* @description
* This function should be called from MSG_onStartup() to provide MSG with
* the data buffer. The first parameter @p sto[] is the address of the memory
* block, and the second parameter @p stoSize is the size of this block
* in bytes. Currently the size of the MSG buffer cannot exceed 64KB.
*
* @note MSG can work with quite small data buffers, but you will start losing
* data if the buffer is too small for the bursts of tracing activity.
* The right size of the buffer depends on the data production rate and
* the data output rate. MSG offers flexible filtering to reduce the data
* production rate.
*
* @note If the data output rate cannot keep up with the production rate,
* MSG will start overwriting the older data with newer data. This is
* consistent with the "last-is-best" MSG policy. The record sequence counters
* and check sums on each record allow the MSGPY host uitiliy to easily detect
* any data loss.
*/
void MSG_initBuf(uint8_t sto[], uint_fast16_t stoSize) {
    /* the provided buffer must be at least 8 bytes long */
    Q_REQUIRE_ID(100, stoSize > (uint_fast16_t)8);

    MSG_priv_.buf      = &sto[0];
    MSG_priv_.end      = (uint16_t)stoSize;
    MSG_priv_.head     = (uint16_t)0;
    MSG_priv_.tail     = (uint16_t)0;
    MSG_priv_.used     = (uint16_t)0;
    MSG_priv_.seq      = (uint8_t)0;
    MSG_priv_.chksum   = (uint8_t)0;
    MSG_priv_.critNest = (uint_fast8_t)0;

    /* produce an empty record to "flush" the MSG trace buffer */
    MSG_beginRec((uint_fast8_t)MSG_EMPTY);
    MSG_endRec();

    /* wait with flushing after successful initialization (see MSG_INIT()) */
}
/****************************************************************************/
/**
* @description
* This function must be called at the beginning of each MSG record.
* This function should be called indirectly through the macro #MSG_BEGIN,
* or #MSG_BEGIN_NOCRIT, depending if it's called in a normal code or from
* a critical section.
*/
void MSG_beginRec(uint_fast8_t rec) {
    uint8_t b      = (uint8_t)(MSG_priv_.seq + (uint8_t)1);
    uint8_t chksum = (uint8_t)0;      /* reset the checksum */
    uint8_t *buf   = MSG_priv_.buf;    /* put in a temporary (register) */
    uint16_t head  = MSG_priv_.head;   /* put in a temporary (register) */
    uint16_t end   = MSG_priv_.end;    /* put in a temporary (register) */

    MSG_priv_.seq = b; /* store the incremented sequence num */
    MSG_priv_.used += (uint16_t)2; /* 2 bytes about to be added */

    MSG_INSERT_ESC_BYTE(b)

    chksum = (uint8_t)(chksum + (uint8_t)rec); /* update checksum */
    MSG_INSERT_BYTE((uint8_t)rec) /* rec byte does not need escaping */

    MSG_priv_.head   = head;   /* save the head */
    MSG_priv_.chksum = chksum; /* save the checksum */
}

/****************************************************************************/
/**
* @description
* This function must be called at the end of each MSG record.
* This function should be called indirectly through the macro #MSG_END,
* or #MSG_END_NOCRIT, depending if it's called in a normal code or from
* a critical section.
*/
void MSG_endRec(void) {
    uint8_t *buf = MSG_priv_.buf;  /* put in a temporary (register) */
    uint16_t   head = MSG_priv_.head;
    uint16_t   end  = MSG_priv_.end;
    uint8_t b = MSG_priv_.chksum;
    b ^= (uint8_t)0xFFU;   /* invert the bits in the checksum */

    MSG_priv_.used += (uint16_t)2; /* 2 bytes about to be added */

    if ((b != MSG_FRAME) && (b != MSG_ESC)) {
        MSG_INSERT_BYTE(b)
    }
    else {
        MSG_INSERT_BYTE(MSG_ESC)
        MSG_INSERT_BYTE(b ^ MSG_ESC_XOR)
        ++MSG_priv_.used; /* account for the ESC byte */
    }

    MSG_INSERT_BYTE(MSG_FRAME) /* do not escape this MSG_FRAME */

    MSG_priv_.head = head; /* save the head */

    /* overrun over the old data? */
    if (MSG_priv_.used > end) {
        MSG_priv_.used = end;   /* the whole buffer is used */
        MSG_priv_.tail = head;  /* shift the tail to the old data */
    }
}
/****************************************************************************/
/**
* @description
* @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_u8(uint8_t format, uint8_t d) {
    uint8_t chksum = MSG_priv_.chksum; /* put in a temporary (register) */
    uint8_t *buf   = MSG_priv_.buf;    /* put in a temporary (register) */
    uint16_t   head   = MSG_priv_.head;   /* put in a temporary (register) */
    uint16_t   end    = MSG_priv_.end;    /* put in a temporary (register) */

    MSG_priv_.used += (uint16_t)2; /* 2 bytes about to be added */

    MSG_INSERT_ESC_BYTE(format)
    MSG_INSERT_ESC_BYTE(d)

    MSG_priv_.head   = head;   /* save the head */
    MSG_priv_.chksum = chksum; /* save the checksum */
}

/****************************************************************************/
/**
* @description
* This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_u16(uint8_t format, uint16_t d) {
    uint8_t chksum = MSG_priv_.chksum; /* put in a temporary (register) */
    uint8_t *buf   = MSG_priv_.buf;    /* put in a temporary (register) */
    uint16_t   head   = MSG_priv_.head;   /* put in a temporary (register) */
    uint16_t   end    = MSG_priv_.end;    /* put in a temporary (register) */

    MSG_priv_.used += (uint16_t)3; /* 3 bytes about to be added */

    MSG_INSERT_ESC_BYTE(format)

    format = (uint8_t)d;
    MSG_INSERT_ESC_BYTE(format)

    d >>= 8;
    format = (uint8_t)d;
    MSG_INSERT_ESC_BYTE(format)

    MSG_priv_.head   = head;   /* save the head */
    MSG_priv_.chksum = chksum; /* save the checksum */
}

/****************************************************************************/
/**
* @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_u32(uint8_t format, uint32_t d) {
    uint8_t chksum = MSG_priv_.chksum; /* put in a temporary (register) */
    uint8_t *buf   = MSG_priv_.buf;    /* put in a temporary (register) */
    uint16_t   head   = MSG_priv_.head;   /* put in a temporary (register) */
    uint16_t   end    = MSG_priv_.end;    /* put in a temporary (register) */
    int_fast8_t   i;

    MSG_priv_.used += (uint16_t)5; /* 5 bytes about to be added */
    MSG_INSERT_ESC_BYTE(format) /* insert the format byte */

    /* insert 4 bytes... */
    for (i = (int_fast8_t)4; i != (int_fast8_t)0; --i) {
        format = (uint8_t)d;
        MSG_INSERT_ESC_BYTE(format)
        d >>= 8;
    }

    MSG_priv_.head   = head;   /* save the head */
    MSG_priv_.chksum = chksum; /* save the checksum */
}

/****************************************************************************/
/*! output uint8_t data element without format information */
/** @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_u8_(uint8_t d) {
    uint8_t chksum = MSG_priv_.chksum; /* put in a temporary (register) */
    uint8_t *buf = MSG_priv_.buf;      /* put in a temporary (register) */
    uint16_t   head = MSG_priv_.head;     /* put in a temporary (register) */
    uint16_t   end  = MSG_priv_.end;      /* put in a temporary (register) */

    ++MSG_priv_.used; /* 1 byte about to be added */
    MSG_INSERT_ESC_BYTE(d)

    MSG_priv_.head   = head;    /* save the head */
    MSG_priv_.chksum = chksum;  /* save the checksum */
}

/****************************************************************************/
/**
* @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_u16_(uint16_t d) {
    uint8_t b      = (uint8_t)d;
    uint8_t chksum = MSG_priv_.chksum; /* put in a temporary (register) */
    uint8_t *buf = MSG_priv_.buf;      /* put in a temporary (register) */
    uint16_t   head = MSG_priv_.head;     /* put in a temporary (register) */
    uint16_t   end  = MSG_priv_.end;      /* put in a temporary (register) */

    MSG_priv_.used += (uint16_t)2; /* 2 bytes are about to be added */

    MSG_INSERT_ESC_BYTE(b)

    d >>= 8;
    b = (uint8_t)d;
    MSG_INSERT_ESC_BYTE(b)

    MSG_priv_.head   = head;    /* save the head */
    MSG_priv_.chksum = chksum;  /* save the checksum */
}

/****************************************************************************/
/** @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_u32_(uint32_t d) {
    uint8_t chksum = MSG_priv_.chksum; /* put in a temporary (register) */
    uint8_t *buf = MSG_priv_.buf;      /* put in a temporary (register) */
    uint16_t   head = MSG_priv_.head;     /* put in a temporary (register) */
    uint16_t   end  = MSG_priv_.end;      /* put in a temporary (register) */
    int_fast8_t i;

    MSG_priv_.used += (uint16_t)4; /* 4 bytes are about to be added */
    for (i = (int_fast8_t)4; i != (int_fast8_t)0; --i) {
        uint8_t b = (uint8_t)d;
        MSG_INSERT_ESC_BYTE(b)
        d >>= 8;
    }

    MSG_priv_.head   = head;    /* save the head */
    MSG_priv_.chksum = chksum;  /* save the checksum */
}

/****************************************************************************/
/**
* @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_str_(char_t const *s) {
    uint8_t b      = (uint8_t)(*s);
    uint8_t chksum = MSG_priv_.chksum; /* put in a temporary (register) */
    uint8_t *buf = MSG_priv_.buf;      /* put in a temporary (register) */
    uint16_t   head = MSG_priv_.head;     /* put in a temporary (register) */
    uint16_t   end  = MSG_priv_.end;      /* put in a temporary (register) */
    uint16_t   used = MSG_priv_.used;     /* put in a temporary (register) */

    while (b != (uint8_t)(0)) {
        chksum = (uint8_t)(chksum + b); /* update checksum */
        MSG_INSERT_BYTE(b)  /* ASCII characters don't need escaping */
        MSG_PTR_INC_(s);
        b = (uint8_t)(*s);
        ++used;
    }
    MSG_INSERT_BYTE((uint8_t)0)  /* zero-terminate the string */
    ++used;

    MSG_priv_.head   = head;   /* save the head */
    MSG_priv_.chksum = chksum; /* save the checksum */
    MSG_priv_.used   = used;   /* save # of used buffer space */
}

/****************************************************************************/
/**
* @description
* This function delivers one byte at a time from the MSG data buffer.
*
* @returns the byte in the least-significant 8-bits of the 16-bit return
* value if the byte is available. If no more data is available at the time,
* the function returns ::MSG_EOD (End-Of-Data).
*
* @note MSG_getByte() is __not__ protected with a critical section.
*/
uint16_t MSG_getByte(void) {
    uint16_t ret;
    if (MSG_priv_.used == (uint16_t)0) {
        ret = MSG_EOD; /* set End-Of-Data */
    }
    else {
        uint8_t *buf = MSG_priv_.buf;  /* put in a temporary (register) */
        uint16_t tail   = MSG_priv_.tail; /* put in a temporary (register) */
        ret = (uint16_t)(MSG_PTR_AT_(buf, tail)); /* set the byte to return */
        ++tail; /* advance the tail */
        if (tail == MSG_priv_.end) { /* tail wrap around? */
            tail = (uint16_t)0;
        }
        MSG_priv_.tail = tail; /* update the tail */
        --MSG_priv_.used;      /* one less byte used */
    }
    return ret; /* return the byte or EOD */
}

/****************************************************************************/
/**
* @description
* This function delivers a contiguous block of data from the MSG data buffer.
* The function returns the pointer to the beginning of the block, and writes
* the number of bytes in the block to the location pointed to by @p pNbytes.
* The parameter @p pNbytes is also used as input to provide the maximum size
* of the data block that the caller can accept.
*
* @returns if data is available, the function returns pointer to the
* contiguous block of data and sets the value pointed to by @p pNbytes
* to the # available bytes. If data is available at the time the function is
* called, the function returns NULL pointer and sets the value pointed to by
* @p pNbytes to zero.
*
* @note Only the NULL return from MSG_getBlock() indicates that the MSG buffer
* is empty at the time of the call. The non-NULL return often means that
* the block is at the end of the buffer and you need to call MSG_getBlock()
* again to obtain the rest of the data that "wrapped around" to the
* beginning of the MSG data buffer.
*
* @note MSG_getBlock() is NOT protected with a critical section.
*/
uint8_t const *MSG_getBlock(uint16_t *pNbytes) {
    uint16_t used = MSG_priv_.used; /* put in a temporary (register) */
    uint8_t *buf;

    /* any bytes used in the ring buffer? */
    if (used != (uint16_t)0) {
        uint16_t tail = MSG_priv_.tail;  /* put in a temporary (register) */
        uint16_t end  = MSG_priv_.end;   /* put in a temporary (register) */
        uint16_t n = (uint16_t)(end - tail);
        if (n > used) {
            n = used;
        }
        if (n > (uint16_t)(*pNbytes)) {
            n = (uint16_t)(*pNbytes);
        }
        *pNbytes = (uint16_t)n;      /* n-bytes available */
        buf = &MSG_PTR_AT_(MSG_priv_.buf, tail); /* the bytes are at the tail */

        MSG_priv_.used = (uint16_t)(used - n);
        tail += n;
        if (tail == end) {
            tail = (uint16_t)0;
        }
        MSG_priv_.tail = tail;
    }

    else { /* no bytes available */
        *pNbytes = (uint16_t)0;  /* no bytes available right now */
        buf      = (uint8_t *)0; /* no bytes available right now */
    }
    return buf;
}
/****************************************************************************/
/** @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_mem(uint8_t const *blk, uint8_t size) {
    uint8_t b      = (uint8_t)(MSG_MEM_T);
    uint8_t chksum = (uint8_t)(MSG_priv_.chksum + b);
    uint8_t *buf   = MSG_priv_.buf;  /* put in a temporary (register) */
    uint16_t   head   = MSG_priv_.head; /* put in a temporary (register) */
    uint16_t   end    = MSG_priv_.end;  /* put in a temporary (register) */

    MSG_priv_.used += ((uint16_t)size + (uint16_t)2); /* size+2 bytes to be added */

    MSG_INSERT_BYTE(b)
    MSG_INSERT_ESC_BYTE(size)

    /* output the 'size' number of bytes */
    while (size != (uint8_t)0) {
        b = *blk;
        MSG_INSERT_ESC_BYTE(b)
        MSG_PTR_INC_(blk);
        --size;
    }

    MSG_priv_.head   = head;   /* save the head */
    MSG_priv_.chksum = chksum; /* save the checksum */
}

/****************************************************************************/
/**
* @note This function is only to be used through macros, never in the
* client code directly.
*/
void MSG_str(char_t const *s) {
    uint8_t b      = (uint8_t)(*s);
    uint8_t chksum = (uint8_t)(MSG_priv_.chksum + (uint8_t)MSG_STR_T);
    uint8_t *buf   = MSG_priv_.buf;  /* put in a temporary (register) */
    uint16_t   head   = MSG_priv_.head; /* put in a temporary (register) */
    uint16_t   end    = MSG_priv_.end;  /* put in a temporary (register) */
    uint16_t   used   = MSG_priv_.used; /* put in a temporary (register) */

    used += (uint16_t)2; /* account for the format byte and the terminating-0 */
    MSG_INSERT_BYTE((uint8_t)MSG_STR_T)
    while (b != (uint8_t)(0)) {
        /* ASCII characters don't need escaping */
        chksum = (uint8_t)(chksum + b); /* update checksum */
        MSG_INSERT_BYTE(b)
        MSG_PTR_INC_(s);
        b = (uint8_t)(*s);
        ++used;
    }
    MSG_INSERT_BYTE((uint8_t)0) /* zero-terminate the string */

    MSG_priv_.head   = head;    /* save the head */
    MSG_priv_.chksum = chksum;  /* save the checksum */
    MSG_priv_.used   = used;    /* save # of used buffer space */
}

/*! QSPY record being processed */
typedef struct {
    uint8_t const *start; /*!< start of the record */
    uint8_t const *pos;   /*!< current position in the stream */
    uint32_t tot_len;     /*!< total length of the record (including chksum) */
    int32_t  len;         /*!< current length of the stream */
    uint8_t  rec;         /*!< the record-ID (see enum QSpyRecords in qs.h) */
} QSpyRecord;

void QSpyRecord_init(QSpyRecord * const me,
                     uint8_t const *start, uint32_t tot_len)
{
    me->start   = start;
    me->tot_len = tot_len;
    me->pos     = start + 2;
    me->len     = tot_len - 3U;
    me->rec     = start[1];
}
typedef enum {
    QSPY_ERROR,
    QSPY_SUCCESS
} QSpyStatus;

QSpyStatus QSpyRecord_OK(QSpyRecord * const me) {
    if (me->len != (uint8_t)0) {
    	QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
    		QS_U8(0, MSG_ERROR_LENGTH);
    		QS_U8(0, me->rec);
    		QS_U8(0, me->len);
    	QS_END()
        return QSPY_ERROR;
    }
    return QSPY_SUCCESS;
}
uint32_t QSpyRecord_getUint32(QSpyRecord * const me, uint8_t size) {
    uint32_t ret = (uint32_t)0;

    if (me->len >= size) {
        if (size == (uint8_t)1) {
            ret = (uint32_t)me->pos[0];
        }
        else if (size == (uint8_t)2) {
            ret = (((uint32_t)me->pos[1] << 8) | (uint32_t)me->pos[0]);
        }
        else if (size == (uint8_t)4) {
            ret = ((((((uint32_t)me->pos[3] << 8)
                        | (uint32_t)me->pos[2]) << 8)
                          | (uint32_t)me->pos[1]) << 8)
                            | (uint32_t)me->pos[0];
        }
        else {
            Q_ASSERT(0);
        }
        me->pos += size;
        me->len -= size;
    }
    else {
    	QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
    		QS_U8(0, MSG_ERROR_LENGTH);
    		QS_U8(0, me->rec);
    		QS_U8(0, me->len);
    	QS_END()
        me->len = -1;
    }
    return ret;
}
int32_t QSpyRecord_getInt32(QSpyRecord * const me, uint8_t size) {
    int32_t ret = (int32_t)0;

    if (me->len >= size) {
        if (size == (uint8_t)1) {
            ret = (uint32_t)me->pos[0];
            ret <<= 24;
            ret >>= 24; /* sign-extend */
        }
        else if (size == (uint8_t)2) {
            ret = ((uint32_t)me->pos[1] << 8)
                        | (uint32_t)me->pos[0];
            ret <<= 16;
            ret >>= 16; /* sign-extend */
        }
        else if (size == (uint8_t)4) {
            ret = ((((((int32_t)me->pos[3] << 8)
                        | (uint32_t)me->pos[2]) << 8)
                          | (uint32_t)me->pos[1]) << 8)
                            | (uint32_t)me->pos[0];
        }
        else {
            Q_ASSERT(0);
        }
        me->pos += size;
        me->len -= size;
    }
    else {
    	QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
    		QS_U8(0, MSG_ERROR_LENGTH);
    		QS_U8(0, me->rec);
    		QS_U8(0, me->len);
    	QS_END()
        me->len = -1;
    }
    return ret;
}
char const *QSpyRecord_getStr(QSpyRecord * const me) {
    uint8_t const *p;
    int32_t l;

    for (l = me->len, p = me->pos; l > 0; --l, ++p) {
        if (*p == (uint8_t)0) {
            char const *s = (char const *)me->pos;
            me->len = l - 1;
            me->pos = p + 1;
            return s;
        }
    }
	QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
		QS_U8(0, MSG_ERROR_LENGTH);
		QS_U8(0, me->rec);
		QS_U8(0, me->len);
	QS_END()
    me->len = -1;
    return "";
}
uint8_t const *QSpyRecord_getMem(QSpyRecord * const me, uint32_t *pLen) {
    if ((me->len >= 1) && ((*me->pos) <= me->len)) {
        uint8_t const *mem = me->pos + 1;
        *pLen = *me->pos;
        me->len -= 1 + *me->pos;
        me->pos += 1 + *me->pos;
        return mem;
    }

	QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
		QS_U8(0, MSG_ERROR_LENGTH);
		QS_U8(0, me->rec);
		QS_U8(0, me->len);
	QS_END()
    me->len = -1;
    *pLen = (uint8_t)0;

    return (uint8_t *)0;
}

static void QSpyRecord_processUser(QSpyRecord * const me) {
	uint8_t fmt;
	uint32_t u32;
	AppEvt* pe = Q_NEW(AppEvt, NUS_SIG);
	pe->type = me->rec; // NUS message type

    while (me->len > 0) {
        fmt = (uint8_t)QSpyRecord_getUint32(me, 1);  /* get the format byte */

        switch (fmt) {
		case MSG_I8_T:
			pe->param[0] = QSpyRecord_getInt32(me, 1);
			break;
		case MSG_U8_T:
			pe->param[1] = QSpyRecord_getUint32(me, 1);
			break;

		case MSG_I16_T:
			pe->param[2] = QSpyRecord_getInt32(me, 2);
			break;
		case MSG_U16_T:
			pe->param[2] = QSpyRecord_getUint32(me, 2);
			break;

		case MSG_I32_T:
			pe->param[3] = QSpyRecord_getInt32(me, 4);
			break;
		case MSG_U32_T:
			pe->param[3] = QSpyRecord_getUint32(me, 4);
			break;

		case MSG_STR_T: {
	        char const *s = QSpyRecord_getStr(me);
			break;
		}
		case MSG_MEM_T: {
			uint8_t const *mem = QSpyRecord_getMem(me, &u32);//len = u32
			for(uint8_t i=0; i < 4; ++i)
				pe->param[i] = mem[i];
			break;
		}
		default:
			QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
				QS_U8(0, MSG_ERROR_UNEXPECTED);
				QS_U8(0, me->rec);
				QS_U8(0, fmt);
			QS_END()
			me->len = -1;
			break;
        }
    }
    QF_PUBLISH(&pe->super, me);
}

static void MSG_process(QSpyRecord * const me) {
	uint32_t addr, mem;
    switch (me->rec) {
	/* Session start ...................................................*/
	case MSG_EMPTY: break;/* silently ignore */
	case MSG_PEEK_MEM:
        addr = QSpyRecord_getUint32(me, 4);
        if (QSpyRecord_OK(me)) { // check post condition: did I consume all?
        	// return memory
        	MSG_BEGIN(MSG_PEEK_RES);
        		MSG_U32(addr);
        		MSG_U32(*(const uint32_t*)addr);
        	MSG_END();
        }
		break;
	case MSG_POKE_MEM:
        addr = QSpyRecord_getUint32(me, 4);
        mem  = QSpyRecord_getUint32(me, 4);
        if (QSpyRecord_OK(me)) { // check post condition: did I consume all?
        	*(uint32_t*)addr = mem; // poke into the memory
        }
		break;
	case MSG_PEEK_RES: break;//ignore
	/* User records ....................................................*/
	default:
		QSpyRecord_processUser(me);
		break;
    }
}

// Receive part copied from qspy
void MSG_parse(uint8_t const *buf, uint32_t nBytes) {
#define MAX_MSG_SIZE 64
    static uint8_t record[MAX_MSG_SIZE];
    static uint8_t *pos   = record; /* position within the record */
    static uint8_t chksum = (uint8_t)0;
    static uint8_t esc    = (uint8_t)0;
    static uint8_t seq    = (uint8_t)0;

    for (; nBytes != 0U; --nBytes) {
        uint8_t b = *buf++;

        if (esc) {                /* escaped byte arrived? */
            esc = (uint8_t)0;
            b ^= MSG_ESC_XOR;

            chksum = (uint8_t)(chksum + b);
            if (pos < &record[sizeof(record)]) {
                *pos++ = b;
            }
            else {
                QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
                	QS_U8(0, MSG_ERROR_LENGTH);
                	QS_U8(0, record[1]);
                QS_END()
                chksum = (uint8_t)0; pos = record; esc = (uint8_t)0;
            }
        }
        else if (b == MSG_ESC) {   /* transparent byte? */
            esc = (uint8_t)1;
        }
        else if (b == MSG_FRAME) { /* frame byte? */
            if (chksum != MSG_GOOD_CHKSUM) {
                QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
                	QS_U8(0, MSG_ERROR_CHECKSUM);
                	QS_U8(0, record[1]);
                	QS_U8(0, seq);
                QS_END()
            }
            else if (pos < &record[3]) {
                QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
                	QS_U8(0, MSG_ERROR_LENGTH);
                	QS_U8(0, record[1]);
                	QS_U8(0, seq);
                QS_END()
            }
            else { /* a healty record received */
                QSpyRecord qrec;
                ++seq;
                if (seq != record[0]) {
                    QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
                    	QS_U8(0, MSG_ERROR_LENGTH);
                    	QS_U8(0, record[0]);//jumped to here
                    	QS_U8(0, seq); //from here
                    QS_END()
                }
                seq = record[0];

                QSpyRecord_init(&qrec, record, (int32_t)(pos - record));
                MSG_process(&qrec);
            }

            /* get ready for the next record ... */
            chksum = (uint8_t)0; pos = record; esc = (uint8_t)0;
        }
        else {  /* a regular un-escaped byte */
            chksum = (uint8_t)(chksum + b);
            if (pos < &record[sizeof(record)]) {
                *pos++ = b;
            }
            else {
                QS_BEGIN(TRACE_MSG_ERROR, (void *)0)
                	QS_U8(0, MSG_ERROR_LENGTH);
                QS_END()
                chksum = (uint8_t)0; pos = record; esc = (uint8_t)0;
            }
        }
    } // end for()
}
