#include <Windows.h>
#include <conio.h> // for kbhit()
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

void allwrite(int fd, unsigned char *buf, int len) {
  int sent = 0;
  int rc;

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
}

typedef union {
  unsigned int num;
  unsigned char buf[8196];
} Aligned4Bytes;


#if 0
unsigned char bRunning = 1;
static DWORD WINAPI idleThread(LPVOID par) {
	unsigned int stopcode = 0xFFFFFFFF;
	while(!_kbhit()) Sleep(1000);
    allwrite(wr, (unsigned char*)&stopcode, 4);
	return(bRunning = 0);
}
#endif

int main(int argc, char *argv[]) {
  int rd = -1, wr = -1, rc = -1;
  Aligned4Bytes send, recv;
  //DWORD threadId;
  const char* readfn = "\\\\.\\xillybus_read_32"
	  , * writefn = "\\\\.\\xillybus_write_32";

  wr = _open(writefn, O_WRONLY);
  rd = _open(readfn, O_RDONLY);
  
  //CreateThread(NULL, 1024, &idleThread, NULL, 0, &threadId);

  if (rd < 0) {
    if (errno == ENODEV)
      fprintf(stderr, "(Maybe %s a write-only file?)\n", readfn);

    fprintf(stderr, "Failed to open %s", readfn);
    exit(1);
  }
  if (wr < 0) {
    if (errno == ENODEV)
      fprintf(stderr, "(Maybe %s a write-only file?)\n", writefn);

    fprintf(stderr, "Failed to open %s", writefn);
    exit(1);
  }

  for(; rc;) {
	  char line[40];
    unsigned int n_byte = 0, n_msg;
   ask:
	  printf("How many messages to get from FPGA? ");
	  if(!gets_s(line, sizeof(line))) { // EOF reached
		  fprintf(stderr, "\nError condition received; exiting\n");
		  break;
	  }
    send.num = atoi(line);
    if(send.num <= 0) {
      printf("Exiting loop\n");
      break;
    }

	  for(n_msg = 1; n_byte < 4*n_msg;) {
      allwrite(wr, send.buf, 4);
		  rc = _read(rd, recv.buf, sizeof(recv.buf));
      if ((rc < 0) && (errno == EINTR)) continue;
      if (rc < 0) {
        fprintf(stderr, "_read() failed to read");
        break;
      }
      if (rc == 0) {
        fprintf(stderr, "Reached read EOF.\n");
        break;
      }

		  allwrite(1, recv.buf, rc);
      n_byte += rc;

      send.num = (unsigned int)rand();
    }
  }
 end:
  _close(wr);
  _close(rd);
}
