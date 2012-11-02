#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <math.h>
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
  int sent = 0;
  while (sent < len) {
    int rc = _write(fd, buf + sent, len - sent);
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
}


unsigned char mulaw_compress(float x) {
  const static float MU = 4.0f, BIAS = -50.0f
    , MUxScale = 0.002522068095f
    , CEILING_DIV_LOG1PMU = 158.4404f;
    //ln(2) = 0.693147f
  float fresult;
  float xb = (x - BIAS) * MUxScale;
  if(xb < 0.0f) xb = 0.0f; // bound it
  else if(xb > MU) xb = MU;
  fresult = CEILING_DIV_LOG1PMU * log(xb + 1.0f);
  return (unsigned char)(fresult + 0.5f);//round it
}

#define CMD_CLOSE 0xFFFFFFFF
struct pc2fpga {
  unsigned int u32;
  float f;
};

int __cdecl main(int argc, char *argv[]) {
  struct pc2fpga cmd = {0, 0.f};

#ifdef TALK_TO_FPGA
  DWORD startTick, elapsedMS;
  const char* readfn = "\\\\.\\xillybus_rd"
	  , * writefn = "\\\\.\\xillybus_wr";
  HANDLE tid[1];
  struct xillyfifo fifo;
  struct xillyinfo info;
  unsigned int fifo_size = 4096*4, cur_frame, n_bytes = 0;

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
#endif

  for(;;) {
    unsigned char expected, actual;
    if(argc > 1) cmd.f = (float)atof(argv[1]);
    else {
      printf("Enter a float point number to compress: ");
      for(; ; Sleep(10)) {
        if(_kbhit()) {
          char line[40];
          if(!gets_s(line, sizeof(line))) { // EOF reached
              fprintf(stderr, "\nError; please try again.\n");
          } else {
            cmd.f = (float)atof(line);
            break;
          }
        } // end if(_kbhit())
      } // end for
    } //end(no cmd line argument)
    //Calculate the correct answer

    expected = mulaw_compress(cmd.f);
#ifdef TALK_TO_FPGA
    allwrite(write_fd, (unsigned char*)&cmd, sizeof(cmd));
    n_bytes = 0;
    while(n_bytes < sizeof(unsigned int)) {
      int do_bytes = fifo_request_drain(&fifo, &info);
      if (!do_bytes) return 0;
      if(n_bytes == sizeof(unsigned int)) {
        printf(" %X", *((unsigned int*)info.addr));
        break;
      }
      fifo_drained(&fifo, do_bytes);//return the buffer
      n_bytes += do_bytes;
    } // end while
#else
    actual = expected;
#endif

    if(actual == expected)
      printf("PASS; %f -> expected %d\n", cmd.f, expected);
    else
      printf("FAIL; %f -> expected %d, got %d\n", cmd.f, expected, actual);
  } //end for(;;)

  cmd.u32 = CMD_CLOSE;//Make the FPGA close the rd file
#ifdef TALK_TO_FPGA
  allwrite(write_fd, (unsigned char*)&cmd, sizeof(cmd));

  _close(write_fd);
  _close(read_fd);

  // Wait for threads to exit
  if (WaitForSingleObject(tid[0], INFINITE) != WAIT_OBJECT_0) 
    errorprint("Failed waiting for read_thread to terminate", GetLastError());

  fifo_destroy(&fifo);
#endif
  return 0;
}
