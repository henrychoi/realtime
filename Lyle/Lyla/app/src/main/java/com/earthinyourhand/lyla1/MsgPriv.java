package com.earthinyourhand.lyla1;

public class MsgPriv {
    public byte[] buf; /*!< pointer to the start of the ring buffer */
    public short end  /*!< offset of the end of the ring buffer */
        , head /*!< offset to where next byte will be inserted */
        , tail /*!< offset of where next byte will be extracted */
        , used; /*!< number of bytes currently in the ring buffer */
    public byte  seq;  /*!< the record sequence number */
    public byte  chksum;/*!< the checksum of the current record */

    public byte critNest; /*!< critical section nesting level */

    public MsgPriv() {}
    public MsgPriv(MsgPriv priv, boolean reset) {
        chksum = reset ? 0 : priv.chksum;
        buf  = priv.buf;    /* put in a temporary (register) */
        head = priv.head;   /* put in a temporary (register) */
        end  = priv.end;    /* put in a temporary (register) */
        used = priv.used;
    }

    /*! Frame character of the Msg output protocol */
    static final byte FRAME = 0x7E;

    /*! Escape character of the Msg output protocol */
    static final byte ESC = 0x7D;

    /*! The expected checksum value over an uncorrupted Msg record */
    static final byte GOOD_CHKSUM = -1;//((byte)0xFF);

    /*! Escape modifier of the Msg output protocol */
    /**
     * @description
     * The escaped byte is XOR-ed with the escape modifier before it is inserted
     * into the Msg buffer.
     */
    static final byte ESC_XOR = 0x20;

    /*! Internal Msg macro to insert an un-escaped byte into the Msg buffer */
    void INSERT_BYTE(byte b_) {
        buf[head] = (b_);
        if (++head == end) { // wrap
            head = 0;
        }
    }

    /*! Internal Msg macro to insert an escaped byte into the Msg buffer */
    void INSERT_ESC_BYTE(byte b_, MsgPriv priv_) {
        chksum = (byte) (chksum + (b_));
        if (((b_) != FRAME) && ((b_) != ESC)) {
            INSERT_BYTE(b_);
        } else{
            INSERT_BYTE(ESC);
            INSERT_BYTE((byte) ((b_) ^ ESC_XOR));
            ++priv_.used;
        }
    }

    void endRec(MsgPriv priv) {
        byte b = priv.chksum;
        b ^= -1; /* 0xFF invert the bits in the checksum */

        priv.used += 2; /* 2 bytes about to be added */

        if ((b != FRAME) && (b != ESC)) {
            INSERT_BYTE(b);
        }
        else {
            INSERT_BYTE(ESC);
            INSERT_BYTE((byte)(b ^ ESC_XOR));
            ++priv.used; /* account for the ESC byte */
        }

        INSERT_BYTE(FRAME); /* do not escape this QS_FRAME */

        priv.head = head; /* save the head */

        /* overrun over the old data? */
        if (priv.used > end) {
            priv.used = end;   /* the whole buffer is used */
            priv.tail = head;  /* shift the tail to the old data */
        }
    }

    void save(MsgPriv priv) {
        priv.head   = head;   /* save the head */
        priv.chksum = chksum; /* save the checksum */
    }
};

