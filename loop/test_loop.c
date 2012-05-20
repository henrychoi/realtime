#include <stdio.h>
#include <getopt.h>
#include <unistd.h>
#include <signal.h> // for signal()
#include <pthread.h>
//#include <execinfo.h> // for backtrace()
#include <sys/mman.h> // for mlockall()
#include <native/task.h>
#include <native/timer.h>
#include "loop.h"
#include "llsMQ.h"
#include "gtest/gtest.h"

#define LOOP_FREQ 100
int g_verbosity = 0
  , duration = 0
  , n_worker=1
  , start_period = 1000000000/LOOP_FREQ, dec_ppm = 0;
const char* g_outfn = NULL;
FILE* g_outf = NULL;
#define N_WORKER_MAX 4
struct llsMQ g_q[N_WORKER_MAX];

RTIME abs_start;

struct LoopData { /* the node I am going to shove into q */
  SRTIME jitter;
  RTIME t_work, period;
  int count;
};

unsigned char bTesting = 1;

void* printloop(void *t) {
  printf("print thread starting.\n");

  while (bTesting) {
    if(!bTesting) break;
    rt_task_sleep(10000);

    for(int i = 0; i < n_worker; ++i) {
      struct LoopData loop;
      while(llsMQ_pop(&g_q[i], &loop)) {
	char line[80];
	int bts = sprintf(line
			  //, "%d,%d,%.2f,%lld.%1d,%lld\n"
			  , "%d,%d,%.2f,%.1f,%.1f\n"
			  , i, loop.count, loop.period/1E6f //[ms]
			  , loop.t_work/1000.0f //[us]
			  , loop.jitter/1000.0f)
	  + 1;
	if(g_outf) fprintf(g_outf, "%s", line);
	if(g_verbosity) printf("%s", line);
      }
    }
  }

  printf("print thread exiting.\n");
  return NULL;
}

void warn_upon_switch(int sig __attribute__((unused)))
{
#if BACKTRACE // couldn't compile this for some reason; TODO
  void *bt[32];
  int nentries;
  /* Dump a backtrace of the frame which caused the switch to
     secondary mode: */
  nentries = backtrace(bt,sizeof(bt) / sizeof(bt[0]));
  backtrace_symbols_fd(bt,nentries,fileno(stdout));
#else
  printf("ERROR, Switched to 2ndary mode\n");
#endif
}

void workloop(void *t) {
  Worker* me = (Worker*)t;
  struct LoopData loop;
  loop.count = 0; loop.period = start_period;

  printf("Worker %d starting.\n", me->id);
  // entering primary mode
  rt_task_set_mode(0, T_WARNSW, NULL);/* Ask Xenomai to warn us upon
					 switches to secondary mode. */

  RTIME next = abs_start + loop.period * me->id
    , cur = rt_timer_read();
  while(next < cur) next += loop.period;

  while(bTesting) {
    next += loop.period;
    //printf(".");
    rt_task_sleep_until(next);//blocks /////////////////////
    if(!bTesting) break;

    cur = rt_timer_read();
    loop.jitter = cur - next;//measure jitter

    /* Begin "work" ****************************************/
    me->work(); //rt_task_sleep(100000000); //for debugging

    /* End "work" ******************************************/
    loop.t_work = rt_timer_read() - cur;
    if(llsMQ_push(&g_q[me->id], &loop)) {
    } else { /* Have to throw away data; need to alarm! */
    }
    /* decrement the period by a fraction */
    loop.period -= dec_ppm ? loop.period / (1000000 / dec_ppm) : 0;
    if(loop.period < 1000000) break; /* Limit at 1 ms */
    ++loop.count;
  }

  rt_task_set_mode(T_WARNSW, 0, NULL);// popping out of primary mode
  printf("Worker %d exiting.\n", me->id);
}

TEST(JitterTest, Loop) { 
  int i;
  struct Worker worker[N_WORKER_MAX];

  if(g_outfn) {
    ASSERT_TRUE(g_outf = fopen(g_outfn, "w"));
    ASSERT_GE(fprintf(g_outf, "worker_id,loop,period[ms],work[us],jitter[us]\n")
	      , 0);
  }
  for(i = 0; i < n_worker; ++i) {
    ASSERT_TRUE(llsMQ_alloc(&g_q[i], 5 /* 2^5 */, sizeof(struct LoopData)));
  }

  ASSERT_EQ(/* Avoids memory swapping for this program */
	    mlockall(MCL_CURRENT|MCL_FUTURE)
	    , 0);

  pthread_t print_thread;
  pthread_attr_t attr;
  struct sched_param sched_param;
  pthread_attr_init( &attr );
  sched_param.sched_priority = sched_get_priority_min(SCHED_OTHER);
  pthread_attr_setschedparam(&attr, &sched_param);
  pthread_create(&print_thread, &attr, printloop, NULL);

  abs_start = rt_timer_read();/* get the current time that the threads
				 can base their scheduling on */
  ASSERT_GT(abs_start, 0);
  signal(SIGXCPU, warn_upon_switch);

  /* create the threads to do the timing */
  for(i = 0; i < n_worker; i++) {
    char name[8];/* doc say name is copied -> safe to use stack */
    sprintf(name, "worker%d", i);
    ASSERT_EQ(rt_task_create(&worker[i].task, name
			     , 0 /* default stack size*/
			     , 1 /* 0 is the lowest priority */
			     , T_FPU | T_JOINABLE)
	      , 0);
    worker[i].id = i;
    ASSERT_EQ(rt_task_start(&worker[i].task, &workloop, (void*)&worker[i])
	      , 0);
  }

  sleep(duration); /* Sleep for the defined test duration */

  printf("Shutting down.\n");
  bTesting = 0;/* signal the worker threads to exit then wait for them */

  for (i = 0 ; i < n_worker ; ++i) {
    EXPECT_EQ(rt_task_join(&worker[i].task), 0);
  }
  EXPECT_EQ(pthread_join(print_thread, NULL), 0);

  if(g_outf) {
    fclose(g_outf); g_outf = NULL;
  }
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);

  const char* usage =
    "\n--duration=(10,3600]\n"
    "[--n_worker=[1,16]]\n"
    "[--start_period=[1000000,1000000000]] [--dec_ppm=[0,1000]]\n"
    "[--outfile=<CSV file to record the result>]\n"
    "[--verbosity=[0,2]]\n"
    "Example: --duration=600 --start_period=100000000 --dec_ppm=200 --outfile=1.csv\n";
  static struct option long_options[] = {
    /* explanation of struct option {
       const char *name;
       int has_arg;
       int *flag; NULL: getopt_long returns val
                  else: returns 0, and flag points to a variable that is set to val
		  if option is found, but otherwise left unchanged if option not found
       int val;
       }; */
    {"duration", required_argument, NULL, 'd'},
    {"n_worker", required_argument, NULL, 'w'},
    {"start_period", required_argument, NULL, 's'},
    {"dec_ppm", required_argument, NULL, 'p'},
    {"outfile", required_argument, NULL, 'f'},
    {"verbosity", optional_argument, NULL, 'v'},
    {NULL, no_argument, NULL, 0} /* brackets the end of the options */
  };
  int option_index = 0, c;

  while((c = getopt_long_only(argc, argv, ""/* Not intuitive: cannot be NULL */
			      , long_options, &option_index))
	!= -1) {
    /* Remember there are these external variables:
     * extern char *optarg;
     * extern int optind, opterr, optopt;
     */
    //int this_option_optind = optind ? optind : 1;
    switch (c) {
    case 'v': /* optarg is NULL if I don't specify an arg */
      g_verbosity = optarg ? atoi(optarg) : 1;
      printf("verbosity: %d\n", g_verbosity);
      break;
    case 'd':
      duration = atoi(optarg);
      printf("duration: %d s\n", duration);
      break;
    case 'w':
      n_worker = atoi(optarg);
      printf("worker: %d\n", n_worker);
      break;
    case 's':
      start_period = atoi(optarg);
      printf("start_period: %d ns\n", start_period);
      break;
    case 'p':
      dec_ppm = atoi(optarg);
      printf("dec_ppm: 0.%04d %%\n", dec_ppm);
      break;
    case 'f':
      g_outfn = optarg;
      printf("outfile: %s\n", g_outfn);
      break;
    case 0:
      printf("option %s", long_options[option_index].name);
      if(optarg) printf(" with arg %s", optarg);
      printf ("\n");
      break;
    case '?':/* ambiguous match or extraneous param */
    default:
      printf ("?? getopt returned character code 0%o ??\n", c);
      break;
    }
  }
  if (optind < argc) {
    printf ("non-option ARGV-elements: ");
    while (optind < argc)
      printf ("%s ", argv[optind++]);
    printf ("\n");
  }
  /*
  else {
    fprintf(stderr, "Expected argument after options\n");
    return optind;
  }
  */

  /*
     If there are no more option characters, getopt() returns -1. Then optind is
     the index in argv of the first argv-element that is not an option. 
  */

  if(duration < 10 || duration > 3600
     || n_worker < 1 || n_worker > 16
     || start_period < 1000000 || start_period > 1000000000
     || dec_ppm < 0 || dec_ppm > 1000) {
    fprintf(stderr, "Invalid argument.  Usage:\n%s", usage);
    return -1;
  }

  return RUN_ALL_TESTS();
}
