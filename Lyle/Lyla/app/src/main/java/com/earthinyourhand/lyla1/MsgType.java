package com.earthinyourhand.lyla1;

public interface MsgType {
    public static final byte
            EMPTY = 0, /*!< MSG record for cleanly starting a session */
            PEEK_MEM = 1, // Reading target memory is very handy
            POKE_MEM = 2, // Writing target memory is very handy
            PEEK_RES = 3, // Answer to the peek
            APP_SPECIFIC = 4, // Begin application specific messages
            WPAR_S = APP_SPECIFIC, // Just 1 string arg
            WPAR_0 = 10, // Message with no arg
            WPAR_8 = 20, // Message with just 1 byte arg
            WPAR_16 = 30, // Message with just 2 byte arg
            STATE = WPAR_16,
            WPAR_32 = 40; // Message with just 4 byte arg
}