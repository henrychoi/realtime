#ifndef xillybus_fifo
#define xillybus_fifo

#include <Windows.h>

// Windows equivalents for gcc builtin atomic operations
#define __sync_add_and_fetch(x,y) (InterlockedExchangeAdd(x, (y)) + (y))
#define __sync_sub_and_fetch(x,y) (InterlockedExchangeAdd(x, -(y)) - (y))

struct xillyfifo {
  LONG read_total;
  LONG write_total;
  LONG bytes_in_fifo;
  unsigned int read_position;
  unsigned int write_position;
  unsigned int size;
  unsigned int done;
  unsigned char *baseaddr;
  HANDLE write_event;
  HANDLE read_event;   
};

struct xillyinfo {
  int slept;
  int bytes;
  int position;
  void *addr;
};

#define FIFO_BACKOFF 0
/*********************************************************************
 *                                                                   *
 *                 A P I   F U N C T I O N S                         *
 *                                                                   *
 *********************************************************************/

// IMPORTANT:
// =========
//
// NEITHER of the fifo_* functions is reentrant. Only one thread should have
// access to any set of them. This is pretty straightforward when one thread
// writes and one thread reads from the FIFO.
//
// Also make sure that fifo_drained() and fifo_wrote() are NEVER called with
// req_bytes larger than what their request-counterparts RETURNED, or
// things will go crazy pretty soon.
int fifo_init(struct xillyfifo *fifo, unsigned int size);
void fifo_done(struct xillyfifo *fifo);
void fifo_destroy(struct xillyfifo *fifo);
int fifo_request_drain(struct xillyfifo *fifo, struct xillyinfo *info);
void fifo_drained(struct xillyfifo *fifo, int req_bytes);
int fifo_request_write(struct xillyfifo *fifo, struct xillyinfo *info);
void fifo_wrote(struct xillyfifo *fifo, int req_bytes);

// Helper
void errorprint(char *what, DWORD dw);

#endif//xillybus_fifo
