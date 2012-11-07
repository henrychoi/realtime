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
  unsigned int n_patch, n_frame = 0;
  for(n_patch = 0; ;) {
    int i, rd_bytes = fifo_request_drain(fifo, &info, 1);//block for reply
    //Loaned "rd_bytes" number of bytes from FIFO vvvvvvvvvvvvvvvvvvvvvvvvv
    if(rd_bytes < 0) continue;// Nothing to read! Not an error in this case
    if(!rd_bytes) break; //FIFO closed.  Do NOT check fifo->done
    if((rd_bytes & 0x3) != 0) {
      fprintf(stderr, "fifo_request_drain returned non-aligned data %d bytes"
          , rd_bytes);
      return rd_bytes;
    }
    for(i = 0; i < (rd_bytes >> 2); ++i, ++n_patch) {
      unsigned int msg = *(((unsigned int*)info.addr) + i);
      //If SOF, the FPGA sends
      //output_data <= #DELAY {`FALSE, `TRUE // !EOF, SOF
      //        , 10'h000, n_frame};
      if(msg >= 0x40000000) {
        n_frame = msg & 0xFFFFF;
        n_patch = 0;
		printf("SOF %d\n", n_frame);
      }
      //printf("%3d, %08d: 0x%08X\n", n_frame, n_patch, msg);
    }
    fifo_drained(fifo, rd_bytes);//return ALL bytes I borrowed ^^^^^^^^^^^^
  }
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

#define CMD_CLOSE 0xFFFFFFFF
struct pc2fpga {
  unsigned int i;
  float f;
};

int __cdecl main(int argc, char *argv[]) {
#define LFSR_SIZE 12
#define N_FRAME 100
#define N_CAM 3
#define N_PATCH 600000//(1<<LFSR_SIZE)
  struct pc2fpga cmd = {0, 0.f};
  const char* readfn = "\\\\.\\xillybus_rd"
	  , * writefn = "\\\\.\\xillybus_wr";
  HANDLE tid[2];
  struct xillyfifo fifo;
  unsigned int fifo_size = 4096*16;
  int i, write_fd, bTalk2FPGA = (int)(argc < 2);
  unsigned short random[N_CAM], lsft_ctr = 0;
  int random_offset = -1; //Galois LFSR never hits 0, so I have to subtract 1
#define INTERFRAME 1
#define INTRAFRAME 2
  unsigned state = INTERFRAME;
  unsigned int n_frame = 0;

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
    if ((fifo_size > 20000)
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

#if (LFSR_SIZE == 3)
#define LFSR_TAP 0x6  //'b110
#elif (LFSR_SIZE == 4)
#define LFSR_TAP 0xC  //'b1100
#elif (LFSR_SIZE == 5)
#define LFSR_TAP 0x14 //'b1_0100
#elif (LFSR_SIZE == 6)
#define LFSR_TAP 0x30 //'b11_0000
#elif (LFSR_SIZE == 7)
#define LFSR_TAP 0x60 //'b110_0000
#elif (LFSR_SIZE == 8)
#define LFSR_TAP 0xB8 //'b1011_1000
#elif (LFSR_SIZE == 9)
#define LFSR_TAP 0x110//'b1_0001_0000
#elif (LFSR_SIZE == 10)
#define LFSR_TAP 0x240//'b10_0100_0000
#elif (LFSR_SIZE == 11)
#define LFSR_TAP 0x500//'b101_0000_0000
#elif (LFSR_SIZE == 12)
#define LFSR_TAP 0xE08//'b1110_0000_1000
#else
# error Unsupported LFSR_SIZE
#endif

  for(i = 0; i < N_CAM; ++i) random[i] = 1 << (LFSR_SIZE-1-i);

  for(; !_kbhit();) {
    //Sleep(100);
    if(state == INTERFRAME) {
      for(i = 0; i < N_CAM; ++i) {
        cmd.i = (1 << (24 + i)) | 0xFFFFF;//SOF
        printf("0x%08X ", cmd.i);
        if(bTalk2FPGA) allwrite(write_fd, (unsigned char*)&cmd, sizeof(cmd));        
      }
      printf("\n");
      state = INTRAFRAME;
    }

    cmd.f = lsft_ctr;
    for(i = 0; i < N_CAM; ++i) {
      cmd.i = (1 << (24 + i)) | (random[i] + random_offset);
      if(bTalk2FPGA) allwrite(write_fd, (unsigned char*)&cmd, sizeof(cmd));
      else printf("0x%08X ", cmd.i);

      random[i] = (random[i] >> 1) ^ (-(random[i] & 1u) & LFSR_TAP);
      if(random[i] > (1<<LFSR_SIZE))
        printf("ERROR");
    } //end for(i)
    if(!bTalk2FPGA)
      printf("\n");

    if(++lsft_ctr == ((1<<LFSR_SIZE) - 1)) { // LSFR rolling over
      lsft_ctr = 0;
      if(random_offset >= (N_PATCH - (1<<LFSR_SIZE))) { // Emit EOF
        for(i = 0; i < N_CAM; ++i) {
          cmd.i = (1 << (24 + i)) | 0xFFFFE;//EOF
          printf("0x%08X ", cmd.i);
          if(bTalk2FPGA) allwrite(write_fd, (unsigned char*)&cmd, sizeof(cmd));
        }
        printf("\n");
        if(++n_frame == N_FRAME)
          break;
        for(i = 0; i < N_CAM; ++i) random[i] = 1 << (LFSR_SIZE-1-i);
        random_offset = -1;
        state = INTERFRAME;
      } else { //Just increase random_offset
        random_offset += (1<<LFSR_SIZE) - 1;
      }
    }
  } //end for(;;)

cleanup:
  printf("Press any key to exit\n");
  getchar();
  cmd.i = CMD_CLOSE;//Make the FPGA close the rd file
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
