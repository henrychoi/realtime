#ifndef msg_pkg_h
#define msg_pkg_h

/****************************************************************************/
/*! Internal MSG macro to insert an un-escaped byte into the MSG buffer */
#define MSG_INSERT_BYTE(b_) \
    MSG_PTR_AT_(buf, head) = (b_); \
    ++head; \
    if (head == end) { \
        head = (uint16_t)0; \
    }

/*! Internal MSG macro to insert an escaped byte into the MSG buffer */
#define MSG_INSERT_ESC_BYTE(b_) \
    chksum = (uint8_t)(chksum + (b_)); \
    if (((b_) != MSG_FRAME) && ((b_) != MSG_ESC)) { \
        MSG_INSERT_BYTE(b_) \
    } \
    else { \
        MSG_INSERT_BYTE(MSG_ESC) \
        MSG_INSERT_BYTE((uint8_t)((b_) ^ MSG_ESC_XOR)) \
        ++MSG_priv_.used; \
    }

/*! Internal MSG macro to increment the given pointer parameter @p ptr_ */
/**
* @note Incrementing a pointer violates the MISRA-C 2004 Rule 17.4(req),
* pointer arithmetic other than array indexing. Encapsulating this violation
* in a macro allows to selectively suppress this specific deviation.
*/
#define MSG_PTR_INC_(ptr_) (++(ptr_))

/*! Frame character of the MSG output protocol */
#define MSG_FRAME    ((uint8_t)0x7E)

/*! Escape character of the MSG output protocol */
#define MSG_ESC      ((uint8_t)0x7D)

/*! The expected checksum value over an uncorrupted MSG record */
#define MSG_GOOD_CHKSUM ((uint8_t)0xFF)

/*! Escape modifier of the MSG output protocol */
/**
* @description
* The escaped byte is XOR-ed with the escape modifier before it is inserted
* into the MSG buffer.
*/
#define MSG_ESC_XOR  ((uint8_t)0x20)

#endif  /* MSG_pkg_h */

