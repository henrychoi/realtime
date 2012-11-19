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
      /*  You don't need to worry about non-32-bit granularity, since _read()
      will never return anything unaligned to the underlying channel, unless
      it has been requested an unaligned number of bytes. This holds for both
      Windows on Linux.  So unless you've done something bizarre such as
      allocating a buffer which isn't 32-bit aligned, or chosen such a
      FIFO_BACKOFF, there's nothing to check. It's pretty simple to verify that
      the two LSBs of all variables in the foodchain are necessarily forced to
      0. */
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

DWORD WINAPI report_thread(LPVOID arg) {
  struct xillyinfo info;  
  struct xillyfifo *fifo = (struct xillyfifo*)arg;
  FILE* of = fopen("reply.bin", "wb");//O_WRONLY | _O_BINARY);
  if(!of) {
    perror("Failed to create result file\n");
    return errno;
  }
  for(; ;) {
    int wc, i
      , rd_bytes = fifo_request_drain(fifo, &info, 1);//block for reply
    //Loaned "rd_bytes" number of bytes from FIFO vvvvvvvvvvvvvvvvvvvvvvvvv
    if(rd_bytes < 0) continue;// Nothing to read! Not an error in this case
    if(!rd_bytes) break; //FIFO closed.  Do NOT check fifo->done
    if((rd_bytes & 0x3) != 0) {
      fprintf(stderr, "fifo_request_drain returned non-aligned data %d bytes"
          , rd_bytes);
      return rd_bytes;
    }
    for(i = 0; i < rd_bytes; ++i) {
      unsigned char msg = *(((unsigned char*)info.addr) + i);
      printf("%02X ", msg);
    }
    for(wc = 0; wc < rd_bytes; ) {
      int new_wc = fwrite((const char*)info.addr + wc, 1, (rd_bytes - wc)
        , of); //_write(of, info.addr, rd_bytes);
      // TODO: Should check for new_wc < 0 (error) and new_wc == 0 (EOF?)
      wc += new_wc;
    }
    fifo_drained(fifo, rd_bytes);//return ALL bytes I borrowed ^^^^^^^^^^^^
  }
  fclose(of);//_close(of);
  return 0;
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

int __cdecl main(int argc, char *argv[]) {
#define N_FRAME 100
#define N_PATCH 600000//(1<<LFSR_SIZE)
  const char* readfn = "\\\\.\\xillybus_rd"
	  , * writefn = "\\\\.\\xillybus_wr";
  HANDLE tid[2];
  struct xillyfifo fifo;
  unsigned int fifo_size = 4096*16;
  int write_fd, bTalk2FPGA = (int)(argc < 2);
  unsigned int n_frame = 0;
  unsigned int msg, n_msg;
  int rd;
  FILE* pixel_coeff_f = fopen("reducer_coeff_0.bin", "rb")
    , *ds_coeff_f = fopen("ds_0.bin", "rb");
  if(!pixel_coeff_f) {
    perror("Failed to open reducer_coeff");
    exit(errno);
  }
  if(!ds_coeff_f) {
    perror("Failed to open ds_coeff");
    exit(errno);
  }

  if(bTalk2FPGA) {
    //printf("Press any key to connect to FPGA\n"); getchar();
    write_fd = _open(writefn, O_WRONLY | _O_BINARY);
    if (write_fd < 0) {
      if (errno == ENODEV)
        fprintf(stderr, "(Maybe %s a write-only file?)\n", writefn);

      fprintf(stderr, "Failed to open %s", writefn);
      exit(1);
    }

    // If more than one FIFO is created, use the total memory needed instead
    // of fifo_size with SetProcessWorkingSetSize()
    if(fifo_size > 20000
      && !SetProcessWorkingSetSize(GetCurrentProcess()
            , 1024*1024 + fifo_size, 2048*1024 + fifo_size))
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
      errorprint("Failed to create read thread", GetLastError());
      exit(1);
    }
    tid[1] = CreateThread(NULL, 0, report_thread, &fifo, 0, NULL);
    if (tid[1] == NULL) {
      errorprint("Failed to create report thread", GetLastError());
      exit(1);
    }
  }//end if(bTalk2FPGA)

  for(n_msg = 0; !feof(pixel_coeff_f); getchar()) {
    rd = fread(&msg, sizeof(msg), 1, pixel_coeff_f);
    if(bTalk2FPGA) allwrite(write_fd, (unsigned char*)&msg, sizeof(msg));
    printf("weights 0x%08X\n", msg);
  } //end for

  for(; !feof(ds_coeff_f); getchar()) {
    rd = fread(&msg, sizeof(msg), 1, ds_coeff_f);
    printf("DS 0x%08X\n", msg);
    if(bTalk2FPGA) allwrite(write_fd, (unsigned char*)&msg, sizeof(msg));
  } //end for

cleanup:
  if(bTalk2FPGA) {
    unsigned int msg = ~0;//Make the FPGA close the rd file
    allwrite(write_fd, (unsigned char*)&msg, sizeof(msg));
    _close(write_fd);
    _close(read_fd);

    // Wait for threads to exit
    if (WaitForSingleObject(tid[0], INFINITE) != WAIT_OBJECT_0) 
      errorprint("Failed waiting for read_thread to terminate"
        , GetLastError());
    fifo_destroy(&fifo);
  }
  fclose(ds_coeff_f);
  fclose(pixel_coeff_f);
  printf("Press any key to exit\n"); getchar();
  return 0;
}
