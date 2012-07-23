#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include "fifo.h"

static int read_fd = 0;

// Write to FIFO, read from standard output
DWORD WINAPI read_thread(LPVOID arg)
{
  struct xillyfifo *fifo = arg;
  int do_bytes, read_bytes;
  struct xillyinfo info;
  unsigned char *buf;

  while (1) {
    do_bytes = fifo_request_write(fifo, &info);

    if (do_bytes == 0)
      return 0;

    for (buf = info.addr; do_bytes > 0;
      buf += read_bytes, do_bytes -= read_bytes) {

      read_bytes = _read(read_fd, buf, do_bytes);
      if ((read_bytes < 0) && (errno != EINTR)) {
	      perror("read() failed");
	      return 0;
      }

      if (read_bytes == 0) {
	      // Reached EOF. Quit without complaining.
	      fifo_done(fifo);
	      return 0;
      }

      if (read_bytes < 0) { // errno is EINTR
	      read_bytes = 0;
	      continue;
      }
      
      fifo_wrote(fifo, read_bytes);
    }
  }
}

void allwrite(int fd, unsigned char *buf, int len) {
  int sent = 0, rc;
  while (sent < len) {
    rc = _write(fd, buf + sent, len - sent);
    if ((rc < 0) && (errno == EINTR))
      continue;

    if (rc < 0) {
      perror("allwrite() failed to write");
      exit(1);
    }

    if (rc == 0) {
      fprintf(stderr, "Reached write EOF (?!)\n");
      exit(1);
    }

    sent += rc;
  }
#ifdef ASYNC_WRITE_STREAM
  rc = _write(fd, NULL, 0);//flush
  if(rc) {
    fprintf(stderr, "Flush failed\n");
    exit(1);
  }
#endif
}

int __cdecl main(int argc, char *argv[]) {
  const char *readfn = "\\\\.\\xillybus_rd"
	  , *loopfn = "\\\\.\\xillybus_rd_loop"
	  , *writefn = "\\\\.\\xillybus_wr";
  unsigned char buf[100];
  HANDLE tid[1];
  DWORD startTick, elapsedMS;
  struct xillyfifo fifo;
  struct xillyinfo info;
  unsigned int fifo_size = 4096*16, n_frame = 0, cur_frame, n_bytes = 0;
  int read_bytes;
  int loop_fd, write_fd = _open(writefn, O_WRONLY | _O_BINARY);
  if (write_fd < 0) {
    if (errno == ENODEV)
      fprintf(stderr, "(Maybe %s a write-only file?)\n", writefn);

    fprintf(stderr, "Failed to open %s", writefn);
    exit(1);
  }

  // If more than one FIFO is created, use the total memory needed instead
  // of fifo_size with SetProcessWorkingSetSize()
  if ((fifo_size > 20000) &&
      !SetProcessWorkingSetSize(GetCurrentProcess(),
				1024*1024 + fifo_size,
				2048*1024 + fifo_size))
    errorprint("Failed to enlarge unswappable RAM limit", GetLastError());

  if (fifo_init(&fifo, fifo_size)) {
    perror("Failed to init");
    exit(1);
  }

  read_fd = _open(readfn, O_RDONLY | _O_BINARY);
  if (read_fd < 0) {
    perror("Failed to open read file");
    exit(1);
  }

  loop_fd = _open(loopfn, O_RDONLY | _O_BINARY);
  if (loop_fd < 0) {
    perror("Failed to open loopback file");
    exit(1);
  }

  if (_setmode(1, _O_BINARY) < 0)
    fprintf(stderr, "Failed to set binary mode for standard output\n");

  // default security, default stack size, default startup flags
  tid[0] = CreateThread(NULL, 0, read_thread, &fifo, 0, NULL);
  if (tid[0] == NULL) {
    errorprint("Failed to create thread", GetLastError());
    exit(1);
  }

  n_frame = argc < 2 ? 1000 : atoi(argv[1]);
  allwrite(write_fd, &n_frame, sizeof(n_frame));

  //read_bytes = _read(loop_fd, buf, sizeof(buf));

  cur_frame = n_frame;
  startTick = GetTickCount();
  while(n_bytes < (n_frame * 4)) {
    int do_bytes;
    //printf(".");
    if (!(do_bytes = fifo_request_drain(&fifo, &info))) {
      return 0;
    }
    if((n_bytes & 0x3) == 0) {
      printf(" %X", *((unsigned int*)info.addr));
    }
    fifo_drained(&fifo, do_bytes);//return the buffer
    n_bytes += do_bytes;
  }
  elapsedMS = GetTickCount() - startTick;
  printf("\n%.1f MB / %.3f sec = %.1f MB/s\n"
    , n_bytes/(1024.f * 1024.f)
    , elapsedMS/1000.f
    , n_bytes/(1024.0f * 1.024f * elapsedMS));

  n_frame = 0;
  allwrite(write_fd, &n_frame, sizeof(n_frame));

  _close(write_fd);
  _close(read_fd);
  _close(loop_fd);

  // Wait for threads to exit
  if (WaitForSingleObject(tid[0], INFINITE) != WAIT_OBJECT_0) 
    errorprint("Failed waiting for read_thread to terminate", GetLastError());

  fifo_destroy(&fifo);

  return 0;
}
