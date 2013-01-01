#include <io.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "fifo.h"
/*********************************************************************
 *                                                                   *
 *                 D E C L A R A T I O N S                           *
 *                                                                   *
 *********************************************************************/

void errorprint(char *what, DWORD dw) {
  LPVOID lpMsgBuf;
  
  FormatMessage(
		FORMAT_MESSAGE_ALLOCATE_BUFFER | 
		FORMAT_MESSAGE_FROM_SYSTEM |
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		dw,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
		(LPTSTR) &lpMsgBuf,
		0, NULL );
  
  fprintf(stderr, "%s: Error=%08x:\n%s\n", what, dw, lpMsgBuf); 
  
  LocalFree(lpMsgBuf);
}

int fifo_init(struct xillyfifo *fifo, unsigned int size) {

  fifo->baseaddr = NULL;
  fifo->size = 0;
  fifo->bytes_in_fifo = 0;
  fifo->read_position = 0;
  fifo->write_position = 0;
  fifo->read_total = 0;
  fifo->write_total = 0;
  fifo->done = 0;

  // No security attributes, autoreset, unnamed
  fifo->read_event = CreateEvent(NULL, FALSE, FALSE, NULL); // Initially nonsignaled
  fifo->write_event = CreateEvent(NULL, FALSE, TRUE, NULL); // Initially signaled
   
  fifo->baseaddr = malloc(size);

  if (!fifo->baseaddr)
    return -1;

  if (!VirtualLock(fifo->baseaddr, size)) {    
    unsigned int i;
    unsigned char *buf = fifo->baseaddr;

    errorprint("Failed to lock RAM, so FIFO's memory may swap to disk", GetLastError());
    
    // Write something every 1024 bytes (4096 should be OK, actually).
    // Hopefully all pages are in real RAM after this. Better than nothing.

    for (i=0; i<size; i+=1024)
      buf[i] = 0;
  }

  fifo->size = size;

  return 0; // Success
}

void fifo_done(struct xillyfifo *fifo) {
  fifo->done = 1;
  // Get the blocked threads off this FIFO
  if (!SetEvent(fifo->read_event))
    errorprint("fifo_done: Failed to set read event", GetLastError());

  if (!SetEvent(fifo->write_event))
    errorprint("fifo_done: Failed to set write event", GetLastError());
}

void fifo_destroy(struct xillyfifo *fifo) {
  if (!fifo->baseaddr)
    return; // Better safe than SEGV

  VirtualUnlock(fifo->baseaddr, fifo->size);
  free(fifo->baseaddr);
  
  CloseHandle(fifo->read_event);
  CloseHandle(fifo->write_event);

  fifo->baseaddr = NULL;
}

int fifo_request_drain(struct xillyfifo *fifo, struct xillyinfo *info
  , unsigned bWait) {
  int taken = 0;
  unsigned int now_bytes, max_bytes;

  info->slept = 0;
  info->addr = NULL;

  now_bytes = __sync_add_and_fetch(&fifo->bytes_in_fifo, 0);
  while (now_bytes == 0 && bWait) {
    if (fifo->done)
      goto fail; // FIFO will not be used by other side, and is empty

    // fifo_wrote() updates bytes_in_fifo and then sets the event,
    // so there's no chance for oversleeping. On the other hand, it's 
    // possible that the data was drained between the bytes_in_fifo
    // update and the event setting, leading to a false wakeup.
    // That's why we're in a while loop ( + other race conditions).
    
    info->slept = 1;

    if (WaitForSingleObject(fifo->read_event, INFINITE) != WAIT_OBJECT_0) {
      errorprint("fifo_request_drain: Failed waiting for event", GetLastError());
      goto fail;
    }
    now_bytes = __sync_add_and_fetch(&fifo->bytes_in_fifo, 0);
  }

  max_bytes = fifo->size - fifo->read_position;
  taken = (now_bytes < max_bytes) ? now_bytes : max_bytes;
  info->addr = fifo->baseaddr + fifo->read_position;

 fail:
  info->bytes = taken;
  info->position = fifo->read_position;

  return taken;
}

void fifo_drained(struct xillyfifo *fifo, int req_bytes) {

  unsigned int now_bytes;

  if (req_bytes == 0)
    return;

  now_bytes = __sync_sub_and_fetch(&fifo->bytes_in_fifo, req_bytes);
  __sync_add_and_fetch(&fifo->read_total, req_bytes);
  
  fifo->read_position += req_bytes;

  if (fifo->read_position >= fifo->size)
    fifo->read_position -= fifo->size;

  if (!SetEvent(fifo->write_event))
    errorprint("fifo_drained: Failed to set write event", GetLastError());
}

int fifo_request_write(struct xillyfifo *fifo, struct xillyinfo *info) {
  int taken = 0;
  unsigned int now_bytes, max_bytes;

  info->slept = 0;
  info->addr = NULL;

  now_bytes = __sync_add_and_fetch(&fifo->bytes_in_fifo, 0);

  if (fifo->done)
    goto fail; // No point filling an abandoned FIFO

  while (now_bytes >= (fifo->size - FIFO_BACKOFF)) {
    // fifo_drained() updates bytes_in_fifo and then sets the event,
    // so there's no chance for oversleeping. On the other hand, it's 
    // possible that the data was drained between the bytes_in_fifo
    // update and the event setting, leading to a false wakeup.
    // That's why we're in a while loop ( + other race conditions).

    info->slept = 1;

    if (WaitForSingleObject(fifo->write_event, INFINITE) != WAIT_OBJECT_0) {
      errorprint("fifo_request_write: Failed waiting for event", GetLastError());
      goto fail;
    }
  
    if (fifo->done)
      goto fail; // No point filling an abandoned FIFO

    now_bytes = __sync_add_and_fetch(&fifo->bytes_in_fifo, 0);
  }

  taken = fifo->size - (now_bytes + FIFO_BACKOFF);

  max_bytes = fifo->size - fifo->write_position;

  if (taken > ((int) max_bytes))
    taken = max_bytes;
  info->addr = fifo->baseaddr + fifo->write_position;

 fail:
  info->bytes = taken;
  info->position = fifo->write_position;

  return taken;
}

void fifo_wrote(struct xillyfifo *fifo, int req_bytes) {
  unsigned int now_bytes;

  if (req_bytes == 0)
    return;

  now_bytes = __sync_add_and_fetch(&fifo->bytes_in_fifo, req_bytes);
  __sync_add_and_fetch(&fifo->write_total, req_bytes);
  
  fifo->write_position += req_bytes;
  
  if (fifo->write_position >= fifo->size)
    fifo->write_position -= fifo->size;
  
  if (!SetEvent(fifo->read_event))
    errorprint("fifo_wrote: Failed to set read event", GetLastError());
}

