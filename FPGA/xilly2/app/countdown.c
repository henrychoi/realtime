#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include "fifo.h"

static int read_fd = 0;

// Read from FIFO, write to standard output
DWORD WINAPI write_thread(LPVOID arg)
{
  struct xillyfifo *fifo = arg;
  int do_bytes;
  struct xillyinfo info;
  unsigned char *buf;

  while (1) {
    if (!(do_bytes = fifo_request_drain(fifo, &info)))
      return 0;
    printf(" %X", *((unsigned int*)info.addr));
    fifo_drained(fifo, 4);
  }
}

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
  int sent = 0;
  int rc;

  while (sent < len) {
    rc = _write(fd, buf + sent, len - sent);
    if ((rc < 0) && (errno == EINTR)) continue;

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
}

int __cdecl main(int argc, char *argv[]) {
  const char* readfn = "\\\\.\\xillybus_read_32"
	  , * writefn = "\\\\.\\xillybus_write_32";
  HANDLE tid[2];
  struct xillyfifo fifo;
  unsigned int fifo_size = 4096;
  unsigned int n_frame;
  int write_fd = _open(writefn, O_WRONLY | _O_BINARY);

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

  if (_setmode(1, _O_BINARY) < 0)
    fprintf(stderr, "Failed to set binary mode for standard output\n");

  // default security, default stack size, default startup flags
  tid[0] = CreateThread(NULL, 0, read_thread, &fifo, 0, NULL);

  if (tid[0] == NULL) {
    errorprint("Failed to create thread", GetLastError());
    exit(1);
  }

  tid[1] = CreateThread(NULL, 0, write_thread, &fifo, 0, NULL);
  
  if (tid[1] == NULL) {
    errorprint("Failed to create thread", GetLastError());
    exit(1);
  }

  while(1) {
    char line[40];
    printf("How many messages to get from FPGA? ");
	  if(!gets_s(line, sizeof(line))) { // EOF reached
		  fprintf(stderr, "\nError condition received; exiting\n");
		  break;
	  }
    n_frame = atoi(line);
    allwrite(write_fd, &n_frame, sizeof(n_frame));
    if(!n_frame) {
      printf("Exiting loop\n");
      break;
    }
  }

  _close(write_fd);
  _close(read_fd);

  // Wait for threads to exit
  if (WaitForSingleObject(tid[0], INFINITE) != WAIT_OBJECT_0) 
    errorprint("Failed waiting for read_thread to terminate", GetLastError());

  if (WaitForSingleObject(tid[1], INFINITE) != WAIT_OBJECT_0) 
    errorprint("Failed waiting for write_thread to terminate", GetLastError());

  fifo_destroy(&fifo);

  return 0;
}
