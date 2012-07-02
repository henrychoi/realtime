#ifndef win32bsp_h
#define win32bsp_h

#define BSP_STACK_SIZE 1024 /* 1K of stack */
#define BSP_TICKS_PER_SEC   1
void BSP_init(int argc, char *argv[]);

#define strtok_r strtok_s
typedef void (*BSPConsoleReplyFn)(const char* msg, uint16_t msgBufferLen
		, void* param);

#endif//win32bsp_h