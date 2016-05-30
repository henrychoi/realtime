#ifndef qs_dummy_h
#define qs_dummy_h

#ifdef Q_SPY
    #error "Q_SPY must NOT be defined to include qs_dummy.h"
#endif

#define QS_INIT(arg_)                   (0 == 0)
#define QS_EXIT()                       ((void)0)
#define QS_DUMP()                       ((void)0)
#define QS_FILTER_ON(rec_)              ((void)0)
#define QS_FILTER_OFF(rec_)             ((void)0)
#define QS_FILTER_SM_OBJ(obj_)          ((void)0)
#define QS_FILTER_AO_OBJ(obj_)          ((void)0)
#define QS_FILTER_MP_OBJ(obj_)          ((void)0)
#define QS_FILTER_EQ_OBJ(obj_)          ((void)0)
#define QS_FILTER_TE_OBJ(obj_)          ((void)0)
#define QS_FILTER_AP_OBJ(obj_)          ((void)0)

#define QS_GET_BYTE(pByte_)             ((uint16_t)0xFFFFU)
#define QS_GET_BLOCK(pSize_)            ((uint8_t *)0)

#define QS_BEGIN(rec_, obj_)            if (0) {
#define QS_END()                        }
#define QS_BEGIN_NOCRIT(rec_, obj_)     if (0) {
#define QS_END_NOCRIT()                 }

#define QS_I8(width_, data_)            ((void)0)
#define QS_U8(width_, data_)            ((void)0)
#define QS_I16(width_, data_)           ((void)0)
#define QS_U16(width_, data_)           ((void)0)
#define QS_I32(width_, data_)           ((void)0)
#define QS_U32(width_, data_)           ((void)0)
#define QS_F32(width_, data_)           ((void)0)
#define QS_F64(width_, data_)           ((void)0)
#define QS_U64(width_, data_)           ((void)0)
#define QS_U32_HEX(width_, data_)       ((void)0)
#define QS_STR(str_)                    ((void)0)
#define QS_MEM(mem_, size_)             ((void)0)
#define QS_SIG(sig_, obj_)              ((void)0)
#define QS_OBJ(obj_)                    ((void)0)
#define QS_FUN(fun_)                    ((void)0)

#define QS_SIG_DICTIONARY(sig_, obj_)   ((void)0)
#define QS_OBJ_DICTIONARY(obj_)         ((void)0)
#define QS_FUN_DICTIONARY(fun_)         ((void)0)
#define QS_USR_DICTIONARY(rec_)         ((void)0)
#define QS_ASSERTION(module_, loc_, delay_) ((void)0)
#define QS_FLUSH()                      ((void)0)

/****************************************************************************/
/* internal QS macros used only in the QP components */
#define QS_CRIT_STAT_
#define QS_BEGIN_(rec_, refObj_, obj_)  if (0) {
#define QS_END_()                       }
#define QS_BEGIN_NOCRIT_(rec_, refObj_, obj_) if (0) {
#define QS_END_NOCRIT_()                }
#define QS_U8_(data_)                   ((void)0)
#define QS_2U8_(data1_, data2_)         ((void)0)
#define QS_U16_(data_)                  ((void)0)
#define QS_U32_(data_)                  ((void)0)
#define QS_U64_(data_)                  ((void)0)
#define QS_TIME_()                      ((void)0)
#define QS_SIG_(sig_)                   ((void)0)
#define QS_EVS_(size_)                  ((void)0)
#define QS_OBJ_(obj_)                   ((void)0)
#define QS_FUN_(fun_)                   ((void)0)
#define QS_EQC_(ctr_)                   ((void)0)
#define QS_MPC_(ctr_)                   ((void)0)
#define QS_MPS_(size_)                  ((void)0)
#define QS_TEC_(ctr_)                   ((void)0)

#define QF_QS_CRIT_ENTRY()              ((void)0)
#define QF_QS_CRIT_EXIT()               ((void)0)
#define QF_QS_ISR_ENTRY(isrnest_, prio_) ((void)0)
#define QF_QS_ISR_EXIT(isrnest_, prio_) ((void)0)
#define QF_QS_ACTION(act_)              ((void)0)

#endif /* qs_dummy_h */
