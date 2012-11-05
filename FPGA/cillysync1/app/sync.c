#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <stdlib.h>
#include <math.h>
#include <io.h> //for _open, _write, _read
#include <conio.h>//for _kbhit
#include "fifo.h"

static int read_fd = 0;

// Write to FIFO, read from standard output
DWORD WINAPI read_thread(LPVOID arg)
{
  struct xillyfifo *fifo = (struct xillyfifo*)arg;
  int rd_bytes, read_bytes;
  struct xillyinfo info;
  unsigned char *buf;

  while (1) {
    //Get a loan from the FIFO for zero copy FIFO write
    rd_bytes = fifo_request_write(fifo, &info); //May write up to this much

    if (rd_bytes == 0)
      return 0;

    for(buf = (unsigned char*)info.addr;
        rd_bytes > 0;
        buf += read_bytes, rd_bytes -= read_bytes) {
      read_bytes = _read(read_fd, buf, rd_bytes);//Read up to the loan

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
      //printf("DEBUG: read_thread: buf %p, %X\n", buf, *buf);
      fifo_wrote(fifo, read_bytes);//Return loaned bytes to FIFO and alert
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

#define CMD_CLOSE 0xFFFFFFFF
struct pc2fpga {
  unsigned int u32;
  float f;
};

int __cdecl main(int argc, char *argv[]) {
#define N_CAM 3
  struct pc2fpga cmd = {0, 0.f};
  DWORD startTick, elapsedMS;
  const char* readfn = "\\\\.\\xillybus_rd"
	  , * writefn = "\\\\.\\xillybus_wr";
  HANDLE tid[1];
  struct xillyfifo fifo;
  struct xillyinfo info;
  unsigned int fifo_size = 4096*4, cur_frame, n_bytes = 0;
  int i, write_fd, bTalk2FPGA = (int)(argc < 2);

  if(bTalk2FPGA) {
    printf("Connecting to FPGA...\n");
    write_fd = _open(writefn, O_WRONLY | _O_BINARY);
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
  }//end if(bTalk2FPGA)

  printf("Press any kep to quit.\n");

  for(; !_kbhit();) {
    unsigned long cams = 7, reply_cams, match, patch_num = 0;
    // Pick a camera and generate a random patch
    cmd.f = 0.f;
    
    if(bTalk2FPGA) {
      int rd_bytes;
      allwrite(write_fd, (unsigned char*)&cmd, sizeof(cmd));//Write to device
      for(n_bytes = 0; n_bytes <= 0; n_bytes += rd_bytes) {
        Sleep(100);
        rd_bytes = fifo_request_drain(&fifo, &info, 0);//don't block for reply
        //Normally, there will not be a response
        //Loaned "rd_bytes" number of bytes from FIFO vvvvvvvvvvvvvvvvvvvvvv
        //I COULD call fifo_drained(0), but that's a NOOP, so don't bother
        if (!rd_bytes) { // Nothing to read!
          break;//Not an error in this case
        }
      } // end while(n_bytes < sizeof(unsigned int))
      if(n_bytes > 0) {
        printf("Received ");
        for(rd_bytes = 0; rd_bytes < n_bytes; rd_bytes++)
          printf(" %02X", *((unsigned char*)info.addr + rd_bytes));
        printf("\n");
      }
      fifo_drained(&fifo, n_bytes);//return ALL bytes I borrowed ^^^^^^^^^^^^
    }
  } //end for(;;)

cleanup:
  printf("Exiting...\n");
  cmd.u32 = CMD_CLOSE;//Make the FPGA close the rd file
  if(bTalk2FPGA) {
    allwrite(write_fd, (unsigned char*)&cmd, sizeof(cmd));

    _close(write_fd);
    _close(read_fd);

    // Wait for threads to exit
    if (WaitForSingleObject(tid[0], INFINITE) != WAIT_OBJECT_0) 
      errorprint("Failed waiting for read_thread to terminate"
      , GetLastError());

    fifo_destroy(&fifo);
  }
  return 0;
}
