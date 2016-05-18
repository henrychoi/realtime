#ifndef app_msg_h
#define app_msg_h

enum MSGType {
    MSG_EMPTY = 0, /*!< MSG record for cleanly starting a session */
	MSG_PEEK_MEM = 1, // Reading target memory is very handy
	MSG_POKE_MEM = 2, // Writing target memory is very handy
	MSG_PEEK_RES = 3, // Answer to the peek
	MSG_APP_SPECIFIC = 4, // Begin application specific messages
	MSG_WPAR_S = 4, // Just 1 string arg
	MSG_WPAR_0 = 10, // Message with no arg
	MSG_WPAR_8 = 20, // Message with just 1 byte arg
	MSG_WPAR_16 = 30, // Message with just 2 byte arg
	MSG_STATE = 30,
	MSG_WPAR_32 = 40, // Message with just 4 byte arg
};

/****************************************************************************/
/*! Initialize the MSG data buffer. */
void MSG_initBuf(uint8_t sto[], uint_fast16_t stoSize);

/*! Mark the begin of a MSG record @p rec */
void MSG_beginRec(uint_fast8_t rec);

/*! Mark the end of a MSG record @p rec */
void MSG_endRec(void);

/* unformatted data elements output ........................................*/
void MSG_u8_(uint8_t d);

/*! Output uint16_t data element without format information */
void MSG_u16_(uint16_t d);

/*! Output uint32_t data element without format information */
void MSG_u32_(uint32_t d);

/*! Output zero-terminated ASCII string element without format information */
void MSG_str_(char_t const *s);

/* formatted data elements output ..........................................*/
/*! Output uint8_t data element with format information */
void MSG_u8(uint8_t format, uint8_t d);

/*! output uint16_t data element with format information */
void MSG_u16(uint8_t format, uint16_t d);

/*! Output uint32_t data element with format information */
void MSG_u32(uint8_t format, uint32_t d);

/*! Output zero-terminated ASCII string element with format information */
void MSG_str(char_t const *s);

/*! Output memory block of up to 255-bytes with format information */
void MSG_mem(uint8_t const *blk, uint8_t size);

/* MSG buffer access *********************************************************/
/*! Byte-oriented interface to the MSG data buffer. */
uint16_t MSG_getByte(void);

/*! Constant for End-Of-Data condition returned from MSG_getByte() */
#define MSG_EOD ((uint16_t)0xFFFF)

/*! Block-oriented interface to the MSG data buffer. */
uint8_t const *MSG_getBlock(uint16_t *pNbytes);


/* platform-specific callback functions, need to be implemented by clients */

/*! Callback to startup the MSG facility */
/**
* @description
* This is a platform-dependent "callback" function invoked through the macro
* #MSG_INIT. You need to implement this function in your application.
* At a minimum, the function must configure the MSG buffer by calling
* MSG_initBuf(). Typically, you will also want to open/configure the MSG output
* channel, such as a serial port, or a data file.
*
* @returns the staus of initialization. Typically 1 (true) when the MSG
* initialization was successful, or 0 (false) when it failed.
*
* @usage
* The following example illustrates an implementation of MSG_onStartup():
* @include qs_startup.c
*/
uint8_t MSG_onStartup();

/****************************************************************************/
/* Macros for adding MSG instrumentation to the client code */

/****************************************************************************/
/* Macros to generate user MSG records */

/*! Begin a MSG user record without entering critical section. */
#define MSG_BEGIN_NOCRIT(rec_, obj_) MSG_beginRec((uint_fast8_t)(rec_))

/*! End a MSG user record without exiting critical section. */
#define MSG_END_NOCRIT() MSG_END_NOCRIT_()

/* MSG-specific critical section *********************************************/
#ifdef MSG_CRIT_ENTRY /* separate MSG critical section defined? */

#ifndef MSG_CRIT_STAT_TYPE
    #define MSG_CRIT_STAT_
    #define MSG_CRIT_ENTRY_()    MSG_CRIT_ENTRY(dummy)
    #define MSG_CRIT_EXIT_()     MSG_CRIT_EXIT(dummy)
#else
    #define MSG_CRIT_STAT_       MSG_CRIT_STAT_TYPE critStat_;
    #define MSG_CRIT_ENTRY_()    MSG_CRIT_ENTRY(critStat_)
    #define MSG_CRIT_EXIT_()     MSG_CRIT_EXIT(critStat_)
#endif

#else /* separate MSG critical section not defined--use the QF definition */

#ifndef QF_CRIT_STAT_TYPE
    /*! This is an internal macro for defining the critical section
    * status type. */
    /**
    * @description
    * The purpose of this macro is to enable writing the same code for the
    * case when critical section status type is defined and when it is not.
    * If the macro #QF_CRIT_STAT_TYPE is defined, this internal macro
    * provides the definition of the critical section status variable.
    * Otherwise this macro is empty.
    * @sa #QF_CRIT_STAT_TYPE
    */
    #define MSG_CRIT_STAT_

    /*! This is an internal macro for entering a critical section. */
    /**
    * @description
    * The purpose of this macro is to enable writing the same code for the
    * case when critical section status type is defined and when it is not.
    * If the macro #QF_CRIT_STAT_TYPE is defined, this internal macro
    * invokes #QF_CRIT_ENTRY passing the key variable as the parameter.
    * Otherwise #QF_CRIT_ENTRY is invoked with a dummy parameter.
    * @sa #QF_CRIT_ENTRY
    */
    #define MSG_CRIT_ENTRY_()    QF_CRIT_ENTRY(dummy)

    /*! This is an internal macro for exiting a critical section. */
    /**
    * @description
    * The purpose of this macro is to enable writing the same code for the
    * case when critical section status type is defined and when it is not.
    * If the macro #QF_CRIT_STAT_TYPE is defined, this internal macro
    * invokes #QF_CRIT_EXIT passing the key variable as the parameter.
    * Otherwise #QF_CRIT_EXIT is invoked with a dummy parameter.
    * @sa #QF_CRIT_EXIT
    */
    #define MSG_CRIT_EXIT_()     QF_CRIT_EXIT(dummy)

#else
    #define MSG_CRIT_STAT_       QF_CRIT_STAT_TYPE critStat_;
    #define MSG_CRIT_ENTRY_()    QF_CRIT_ENTRY(critStat_)

    #define MSG_CRIT_EXIT_()     QF_CRIT_EXIT(critStat_)
#endif

#endif /* MSG_CRIT_ENTRY */

/*! Begin a user MSG record with entering critical section. */
/**
* @usage
* The following example shows how to build a user MSG record using the
* macros #MSG_BEGIN, #MSG_END, and the formatted output macros: #MSG_U8 and
* #MSG_STR.
* @include qs_user.c
* @note Must always be used in pair with #MSG_END
*/
#define MSG_BEGIN(rec_) \
        MSG_CRIT_STAT_ \
        MSG_CRIT_ENTRY_(); \
        MSG_beginRec((uint_fast8_t)(rec_))

/*! End a MSG record with exiting critical section. */
/** @sa example for #MSG_BEGIN
* @note Must always be used in pair with #MSG_BEGIN
*/
#define MSG_END() MSG_END_()

/****************************************************************************/

/*! Internal MSG macro to begin a MSG record with entering critical section. */
/**
* @note This macro is intended to use only inside QP components and NOT
* at the application level. @sa #MSG_BEGIN
*/
#define MSG_BEGIN_(rec_, objFilter_, obj_) \
        MSG_CRIT_ENTRY_(); \
        MSG_beginRec((uint_fast8_t)(rec_))

/*!  Internal MSG macro to end a MSG record with exiting critical section. */
/**
* @note This macro is intended to use only inside QP components and NOT
* at the application level. @sa #MSG_END
*/
#define MSG_END_() \
        MSG_endRec(); \
        MSG_CRIT_EXIT_()

/*! Internal macro to begin a MSG record without entering critical section. */
/**
* @note This macro is intended to use only inside QP components and NOT
* at the application level. @sa #MSG_BEGIN_NOCRIT
*/
#define MSG_BEGIN_NOCRIT_(rec_) MSG_beginRec((uint_fast8_t)(rec_))

/*! Internal MSG macro to end a MSG record without exiting critical section. */
/**
* @note This macro is intended to use only inside QP components and NOT
* at the application level. @sa #MSG_END_NOCRIT
*/
#define MSG_END_NOCRIT_() MSG_endRec()

/*! Internal MSG macro to output an unformatted uint8_t data element */
#define MSG_U8_(data_)           (MSG_u8_((uint8_t)(data_)))

/*! Internal MSG macro to output an unformatted uint16_t data element */
#define MSG_U16_(data_)          (MSG_u16_((uint16_t)(data_)))

/*! Internal MSG macro to output an unformatted uint32_t data element */
#define MSG_U32_(data_)          (MSG_u32_((uint32_t)(data_)))

/*! Internal MSG macro to output a zero-terminated ASCII string element */
#define MSG_STR_(msg_)           (MSG_str_((msg_)))

/* Macros for use in the client code .......................................*/

/*! Enumerates data formats recognized by MSG */
/**
* @description
* MSG uses this enumeration is used only internally for the formatted user
* data elements.
*/
enum {
    MSG_I8_T = 0,          /*!< signed 8-bit integer format */
    MSG_U8_T,              /*!< unsigned 8-bit integer format */
    MSG_I16_T,             /*!< signed 16-bit integer format */
    MSG_U16_T,             /*!< unsigned 16-bit integer format */
    MSG_I32_T,             /*!< signed 32-bit integer format */
    MSG_U32_T,             /*!< unsigned 32-bit integer format */
    MSG_F32_T,             /*!< 32-bit floating point format */
    MSG_F64_T,             /*!< 64-bit floating point format */
    MSG_STR_T,             /*!< zero-terminated ASCII string format */
    MSG_MEM_T,             /*!< up to 255-bytes memory block format */
    MSG_I64_T,             /*!< signed 64-bit integer format */
    MSG_U64_T,             /*!< unsigned 64-bit integer format */
};

#define MSG_I8(data_)  MSG_u8(MSG_I8_T, (data_))
#define MSG_U8(data_)  MSG_u8(MSG_U8_T, (data_))
#define MSG_I16(data_) MSG_u16(MSG_I16_T, (data_))
#define MSG_U16(data_) MSG_u16(MSG_U16_T, (data_))
#define MSG_I32(data_) MSG_u32(MSG_I32_T, (data_))
#define MSG_U32(data_) MSG_u32(MSG_U32_T, (data_))
#define MSG_STR(str_)  MSG_str(str_)

/*! Output formatted memory block of up to 255 bytes to the MSG record */
#define MSG_MEM(mem_, size_) MSG_mem((mem_), (size_))

/****************************************************************************/
//@brief feed the message parser
void MSG_parse(uint8_t const *buf, uint32_t nBytes);

#endif
