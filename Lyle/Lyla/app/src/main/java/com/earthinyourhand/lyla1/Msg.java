package com.earthinyourhand.lyla1;

import android.util.Log;

import java.io.UnsupportedEncodingException;
import java.util.Arrays;
import java.util.concurrent.locks.ReentrantLock;
import android.util.Pair;

public class Msg {
    public static final byte ALL_MSG = ~0;
    static final byte
            I8_T  = 0,
            U8_T  = 1,
            I16_T = 2,
            U16_T = 3,
            I32_T = 4,
            U32_T = 5,
            F32_T = 6,
            F64_T = 7,
            STR_T = 8,
            MEM_T = 9,
            I64_T = 10,
            U64_T = 11
            ;
    public static final short EOD = -1;//0xFFFF

    public void I8(byte data) { i8(I8_T, data); }
    public void U8(byte data) { i8(U8_T, data); }
    public void I16(short data) { i16(I16_T, data); }
    public void U16(short data) { i16(U16_T, data); }
    public void I32(int data) { i32(I32_T, data); }
    public void U32(int data) { i32(U32_T, data); }
    //public void F32(float data) { f32(F32_T, data); }
    //public void F64(double data) { f64(F32_T, data); }
    public void I64(long data) { i64(I64_T, data); }
    public void U64(long data) { i64(U64_T, data); }
    public void STR(String str) {
        MsgPriv temp = new MsgPriv(priv_, false);
        priv_.used += 2;
        temp.INSERT_BYTE(STR_T);
        try {
            byte[] s = str.getBytes("UTF-8");
            for (int i=0; i < s.length; ++i) {
                temp.INSERT_BYTE(s[i]); temp.chksum += s[i]; ++priv_.used;
            }
            temp.INSERT_BYTE((byte)0);
        } catch(UnsupportedEncodingException e) {
            e.printStackTrace();
        }
        temp.save(priv_);
    }
    public void MEM(byte[] blk) {
        MsgPriv temp = new MsgPriv(priv_, false);
        priv_.used += blk.length + 2;
        temp.INSERT_BYTE(MEM_T);
        temp.INSERT_ESC_BYTE((byte)blk.length, priv_);
        for (int i=0; i < blk.length; ++i) {
            temp.INSERT_ESC_BYTE(blk[i], priv_);
        }
        temp.save(priv_);
    }

    /**
     * @description
     * This function delivers one byte at a time from the Msg data buffer.
     *
     * @returns the byte in the least-significant 8-bits of the 16-bit return
     * value if the byte is available. If no more data is available at the time,
     * the function returns ::QS_EOD (End-Of-Data).
     *
     * @note QS_getByte() is __not__ protected with a critical section.
     */
    public short getByte() {
        try {
            mLock.lock();
            if (priv_.used == 0) {
                return EOD;
            }
            //uint8_t *buf = priv_.buf;  /* put in a temporary (register) */
            short tail = priv_.tail; /* put in a temporary (register) */
            short ret = priv_.buf[tail]; /* set the byte to return */
            if (++tail == priv_.end) { /* tail wrap around? */
                tail = 0;
            }
            priv_.tail = tail; /* update the tail */
            --priv_.used;      /* one less byte used */
            return ret;
        } finally {
            mLock.unlock();
        }
    }

    /**
     * @description
     * This function delivers a contiguous block of data from the Msg data buffer.
     * The function returns the pointer to the beginning of the block, and writes
     * the number of bytes in the block to the location pointed to by @p pNbytes.
     * The parameter @p pNbytes is also used as input to provide the maximum size
     * of the data block that the caller can accept.
     *
     * @returns if data is available, the function returns index to the
     * contiguous block of data and sets the value pointed to by @p N
     * to the # available bytes. If no data is available at the time the function is
     * called, the function returns -1 and sets the value pointed to by
     * @p pNbytes to zero.
     *
     * @note Only the -1 return from QS_getBlock() indicates that the Msg buffer
     * is empty at the time of the call. The non-negative return often means that
     * the block is at the end of the buffer and you need to call QS_getBlock()
     * again to obtain the rest of the data that "wrapped around" to the
     * beginning of the Msg data buffer.
     *
     * @note QS_getBlock() is NOT protected with a critical section.
     */
    public Pair<Short, Short> getBlock(short N) {
        try {
            mLock.lock();
            short used = priv_.used; /* put in a temporary (register) */
            if (used == 0) { /* no bytes available */
                N = 0;  /* no bytes available right now */
                return null; /* no bytes available right now */
            }

            short tail = priv_.tail,  /* put in a temporary (register) */
                    end = priv_.end,   /* put in a temporary (register) */
                    n = (short) (end - tail);
            if (n > used) {
                n = used;
            }
            if (n > N) {
                n = N;
            }
            N = n;      /* n-bytes available */
            Pair<Short, Short> ret = Pair.create(tail, N); /* the (pending) bytes are at the tail */

            priv_.used = (short) (used - n);
            tail += n;
            if (tail == end) {
                tail = 0;
            }
            priv_.tail = tail;
            return ret;
        } finally {
            mLock.unlock();
        }
    }

    public void FLUSH() {
        ifc.flushTX();
    }

    public void BEGIN(byte rec) {
        mLock.lock();//END() will unlock
        beginRec(rec);//Note: timestamp NOT a part of the message
    }
    public void END() {
        endRec();
        mLock.unlock();
    }

    //@param sto We adopt the model of the user of the Msg loaning the buffer to Msg,
    // so that getBlock() can return an index to the loaned buffer.
    public Msg(byte[] sto, short stoSize, Msgable ifc) {
        priv_.buf = sto;
        priv_.end = stoSize;
        this.ifc = ifc;

        /* produce an empty record to "flush" the Msg trace buffer */
        beginRec(MsgType.EMPTY);
        endRec();
    }

    // end public /////////////////////////////////////////////////////////////
    MsgPriv priv_ = new MsgPriv();
    Msgable ifc;
    //filterOff() unimplemented

    /**
     * @description
     * This function must be called at the beginning of each Msg record.
     * This function should be called indirectly through the macro #BEGIN,
     * or #BEGIN_NOCRIT, depending if it's called in a normal code or from
     * a critical section.
     */
    void beginRec(byte rec) {
        byte b      = (byte)(priv_.seq + 1);

        MsgPriv temp = new MsgPriv(priv_, true);

        priv_.seq = b; /* store the incremented sequence num */
        priv_.used += (short)2; /* 2 bytes about to be added */

        temp.INSERT_ESC_BYTE(b, priv_);

        temp.chksum = (byte)(temp.chksum + (byte)rec); /* update checksum */
        temp.INSERT_BYTE((byte)rec); /* rec byte does not need escaping */
        temp.save(priv_);
    }

    /**
     * @description
     * This function must be called at the end of each Msg record.
     * This function should be called indirectly through the macro #END,
     * or #END_NOCRIT, depending if it's called in a normal code or from
     * a critical section.
     */
    void endRec() {
        MsgPriv temp = new MsgPriv(priv_, true);
        temp.endRec(priv_);
    }

    void I8_(byte data_) { i8_(data_); }
    void _2I8_(byte data1_, byte data2_) { i8i8_(data1_, data2_); }
    void I16_(short data_) { i16_(data_); }
    void I32_(int data_) { i32_(data_); }
    void STR_(String s) { str_(s); }

    void i8_(byte d) {
        MsgPriv temp = new MsgPriv(priv_, false);
        ++priv_.used; /* 1 byte about to be added */
        temp.INSERT_ESC_BYTE(d, priv_);
        temp.save(priv_);
    }
    void i8(byte format, byte d) {
        MsgPriv temp = new MsgPriv(priv_, false);
        priv_.used += 2; /* 2 bytes about to be added */
        temp.INSERT_ESC_BYTE(format, priv_);
        temp.INSERT_ESC_BYTE(d, priv_);
        temp.save(priv_);
    }

    void i8i8_(byte d1, byte d2) {
        MsgPriv temp = new MsgPriv(priv_, false);
        priv_.used += 2; /* 2 bytes about to be added */
        temp.INSERT_ESC_BYTE(d1, priv_);
        temp.INSERT_ESC_BYTE(d2, priv_);
        temp.save(priv_);
    }
    void i16_(short d) {
        MsgPriv temp = new MsgPriv(priv_, false);

        priv_.used += 2; /* 2 bytes about to be added */
        byte b = (byte)d;
        temp.INSERT_ESC_BYTE(b, priv_);

        d >>= 8; b = (byte)d;
        temp.INSERT_ESC_BYTE(b, priv_);
        temp.save(priv_);
    }
    void i16(byte format, short d) {
        MsgPriv temp = new MsgPriv(priv_, false);
        priv_.used += 3; /* 3 bytes about to be added */
        temp.INSERT_ESC_BYTE(format, priv_);
        format = (byte)d;
        temp.INSERT_ESC_BYTE(format, priv_);
        format = (byte)(d >> 8);
        temp.INSERT_ESC_BYTE(format, priv_);
        temp.save(priv_);
    }

    void i32_(int d) {
        MsgPriv temp = new MsgPriv(priv_, false);

        priv_.used += 4; /* 4 bytes about to be added */
        for (int i=4; i != 0; --i) {
            byte b = (byte) d;
            temp.INSERT_ESC_BYTE(b, priv_);
            d >>= 8;
        }
        temp.save(priv_);
    }
    void i32(byte format, int d) {
        MsgPriv temp = new MsgPriv(priv_, false);
        priv_.used += 5; /* 5 bytes about to be added */
        temp.INSERT_ESC_BYTE(format, priv_);
        for(int i = 4; i != 0; --i) {
            format = (byte) d;
            temp.INSERT_ESC_BYTE(format, priv_);
            d >>= 8;
        }
        temp.save(priv_);
    }

    void i64(byte format, long d) {
        MsgPriv temp = new MsgPriv(priv_, false);
        priv_.used += 9;
        temp.INSERT_ESC_BYTE(format, priv_);
        for(int i = 8; i != 0; --i) {
            format = (byte) d;
            temp.INSERT_ESC_BYTE(format, priv_);
            d >>= 8;
        }
        temp.save(priv_);
    }

    void str_(String str) {
        MsgPriv temp = new MsgPriv(priv_, false);
        try {
            byte[] s = str.getBytes("UTF-8");
            for (int i=0; i < s.length; ++i) {
                temp.INSERT_ESC_BYTE(s[i], priv_);
                ++priv_.used;
            }
            temp.INSERT_ESC_BYTE((byte)0, priv_);
            ++priv_.used;
        } catch(UnsupportedEncodingException e) {
            e.printStackTrace();
        }
        temp.save(priv_);
    }

    ReentrantLock mLock = new ReentrantLock();

    final static String TAG = Msg.class.getSimpleName();

    //@brief static structure to book-keep the record (which is also static)
    class QSpyRecord {
        public byte pos, tot_len, len, rec;

        public void init(byte tot_len) {
            this.tot_len = tot_len;
            this.pos = 2;
            this.len = (byte) (tot_len - 3);
            this.rec = record[1];
        }

        //@brief A successfully parsed record should not have any unprocessed bytes
        public boolean OK() {
            if (len != 0) {
                Log.e(TAG, String.format("**********Error in %d: %d bytes unparsed",
                        rec, len));
                return false;
            }
            return true;
        }

        public byte getByte() {
            if (len >= 1) {
                byte ret = record[pos];
                pos++;
                len--;
                return ret;
            }
            Log.e(TAG, "Byte overrun");
            return 0;
        }

        public short getShort() {
            if (len >= 2) {
                short ret = (short) (((short) record[pos + 1] << 8)
                        | record[pos]);
                pos += 2;
                len -= 2;
                return ret;
            }
            Log.e(TAG, "Short overrun");
            return 0;
        }

        public int getInt() {
            if (len >= 4) {
                int ret = ((int) record[pos + 3] << 24)
                        | ((int) record[pos + 2] << 16)
                        | ((int) record[pos + 1] << 8)
                        | record[pos];
                pos += 4;
                len -= 4;
                return ret;
            }
            Log.e(TAG, "Int overrun");
            return 0;
        }

        public String getStr() {
            byte l, p;
            for (l = len, p = pos; l > 0; --l, ++p) {
                if (record[p] == 0) {
                    try {
                        String ret = new String(record, pos, p, "UTF-8");
                    } catch (UnsupportedEncodingException e) {
                        Log.e(TAG, "UTF-8 encoding unsupported");
                        return "";
                    }
                    len = (byte) (l - 1);
                    pos = (byte) (p + 1);
                }
            }
            len = -1;
            Log.e(TAG, "String overrun");
            return "";
        }

        public byte[] getMem() {
            byte mem_len = record[pos];
            if (len >= 1 && mem_len <= len) {
                byte[] ret = Arrays.copyOfRange(record, pos + 1, pos + 1 + mem_len);
                len -= 1 + mem_len;
                pos += 1 + mem_len;
                return ret;
            }
            len = -1;
            Log.e(TAG, "Mem overrun");
            return new byte[0];
        }

        void process() {
            switch(rec) {
                case MsgType.EMPTY:
                case MsgType.PEEK_MEM:
                case MsgType.POKE_MEM:
                    break; //silently ignore
                case MsgType.PEEK_RES:
                    TargetMsg m = new TargetMsg();
                    m.data[0] = getInt();
                    m.data[1] = getInt();
                    ifc.onTargetMsg(m);
                    break;
                default:
                    processUser(); break;
            }
        }
        void processUser() {
            TargetMsg m = new TargetMsg();
            m.typ = rec;

            while (len > 0) {
                byte fmt = getByte();
                switch (fmt) {
                    case I8_T:
                    case U8_T:
                        m.data[0] = getByte();
                        break;
                    case I16_T:
                    case U16_T:
                        m.data[0] = getShort();
                        break;
                    case I32_T:
                    case U32_T:
                        m.data[0] = getInt();
                        break;
                    case STR_T:
                        String s = getStr();
                        break;
                    case MEM_T:
                        byte[] mem = getMem();
                        break;
                    default:
                        Log.e(TAG, String.format("********** %d: Unknown format %d",
                                rec, fmt));
                        len = -1;
                        break;
                }
            }
            ifc.onTargetMsg(m);
        }
    }
    QSpyRecord qrec = new QSpyRecord();
    static final byte MAX_RECORD_SIZE = 64;
    byte[] record = new byte[64];
    byte pos = 0; /* position within the record */
    byte chksum , seq;
    boolean esc;
    synchronized void parse(byte[] buf) {
        for (byte i=0; i < buf.length; ++i) {
            byte b = buf[i];
            if (esc) {                /* escaped byte arrived? */
                esc = false;
                b ^= MsgPriv.ESC_XOR;

                chksum = (byte)(chksum + b);
                if (pos < MAX_RECORD_SIZE) {
                    record[pos++] = b;
                }
                else {
                    Log.e(TAG, "********** Error, record too long");
                    chksum = 0; pos = 0; esc = false;
                }
            }
            else if (b == MsgPriv.ESC) {   /* transparent byte? */
                esc = true;
            }
            else if (b == MsgPriv.FRAME) { /* frame byte? */
                if (chksum != MsgPriv.GOOD_CHKSUM) {
                    Log.e(TAG, String.format("********** Bad checksum at seq=%d, rec=%d",
                                            seq, record[1]));
                }
                else if (pos < 3) {
                    Log.e(TAG, String.format("********** Record too short at seq=%d, rec=%d",
                            seq, record[1]));
                }
                else { /* a healty record received */
                    ++seq;
                    if (seq != record[0]) {
                        Log.e(TAG, String.format("********** Data discontinuity: seq=%d -> seq=%d",
                                seq, record[0]));
                    }
                    seq = record[0];

                    qrec.init(pos);
                    qrec.process();
                }

                /* get ready for the next record ... */
                chksum = 0; pos = 0; esc = false;
            }
            else {  /* a regular un-escaped byte */
                chksum = (byte)(chksum + b);
                if (pos < MAX_RECORD_SIZE) {
                    record[pos++] = b;
                }
                else {
                    Log.e(TAG, "********** Error, record too long");
                    chksum = 0; pos = 0; esc = false;
                }
            }
        } // end for
    }

}
