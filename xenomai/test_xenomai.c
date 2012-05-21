// system calls ///////////////////////////////////////////
#include <stdio.h>
#include <getopt.h>
#include <unistd.h>
#include <signal.h> // for signal()
#include <pthread.h>
//#include <execinfo.h> // for backtrace()
#include <sys/mman.h> // for mlockall()
#include <native/task.h>
#include <native/timer.h>

// 3rd party stuff ////////////////////////////////////////
#include "gtest/gtest.h"
#include "log4cpp/Category.hh"
#include "log4cpp/RollingFileAppender.hh"
#include "log4cpp/BasicLayout.hh"
#include "log4cpp/PatternLayout.hh"

// my code ////////////////////////////////////////////////
#include "CircQ.h"

struct LoopData { /* the node I am going to shove into q */
  SRTIME jitter;
  RTIME t_work, period;
  unsigned long long count;
};

class Worker {
 public:
  unsigned char id;
  RT_TASK thread;
  CircQ<struct LoopData> loopdata_q, late_q;

  virtual ~Worker() {};
 Worker() : loopdata_q(30), late_q(10) {};

 protected:
  void work();
};

using namespace log4cpp;

// globals ////////////////////////////////////////////////
int g_verbosity = 0
  , duration = 0
  , n_worker=N_WORKER
  , start_period = 1000000000/LOOP_FREQ, dec_ppm = 0;

const char* g_outfn = NULL;
FILE* g_outf = NULL;
bool bTesting = 1;
RTIME abs_start;

// functions ////////////////////////////////////////////
Void *printloop(void *t) {
  Worker* worker = (Worker*)t;
  Category& logger = Category::getInstance(__FILE__);
  logger.info("print thread starting.");

  while (bTesting) {
    usleep(10000);// sleep 10 ms, which is a Linux scheduling gradularity

    for(int i = 0; i < n_worker; ++i) {
      struct LoopData loop;

      while(worker[i].loopdata_q.pop(loop)) {
	char line[80];
	int bts = sprintf(line, "%d,%lld,%.2f,%.1f,%.1f\n"
			  , i, loop.count, loop.period/1E6f //[ms]
			  , loop.t_work/1E3f, loop.jitter/1E3F)
	  + 1;
	if(g_outf) fprintf(g_outf, "%s", line);
	if(g_verbosity) printf("%s", line);
      }
    }
  }

  logger.info("print thread exiting.");
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
  Category& logger = Category::getInstance(__FILE__);
  logger.info("Worker %d starting.", me->id);

  struct LoopData loop;
  loop.count = 0;
  loop.period = start_period / n_worker;
  loop.deadline = abs_start + loop.period*me->id;

  // entering primary mode
  rt_task_set_mode(0, T_WARNSW, NULL);/* Ask Xenomai to warn us upon
					 switches to secondary mode. */

  RTIME now = rt_timer_read();
  while(loop.deadline < now) loop.deadline += loop.period;

  while(bTesting) {
    rt_task_sleep_until(loop.deadline);//blocks /////////////////////
    if(!bTesting) break;

    now = rt_timer_read();
    loop.jitter = now - loop.deadline;//measure jitter

    /* Begin "work" ****************************************/
    me->work(); //rt_task_sleep(100000000); //for debugging
    /* End "work" ******************************************/
    RTIME t0 = now;//use an easy to remember var
    now = rt_timer_read();

    // Post work book keeping ///////////////////////////////
    if(!me->late_q.isEmpty()// Manage the late q
       && me->late_q[0].count < (loop.count - 100)) {
      me->late_q.pop(); // if sufficiently old, forget about it
    }

    //to report how much the work took
    loop.t_work = now - t0;
    if(me->loopdata_q.push(loop)) {
    } else { /* Have to throw away data; need to alarm! */
      logger.alert("Loop data full");
    }

    loop.deadline += loop.period;
    if(now > loop.deadline) { // Did I miss the deadline?
      // How badly did I miss the deadline?
      // Definition of "badness": just a simple count over the past N loop
      if(me->late_q.isFull()) { //FATAL
	logger.fatal("Missed too many deadlines");
	break;
      }
    }

    /* decrement the period by a fraction */
    loop.period -= dec_ppm ? loop.period / (1000000 / dec_ppm) : 0;
    if(loop.period < 1000000) break; /* Limit at 1 ms for now */
    ++loop.count;
  }

  rt_task_set_mode(T_WARNSW, 0, NULL);// popping out of primary mode
  logger.info("Worker %d exiting.", me->id);
}

TEST(JitterTest, Loop) { 
  int i;
  Category& logger = Category::getInstance(__FILE__);

  ASSERT_EQ(/* Avoids memory swapping for this program */
	    mlockall(MCL_CURRENT|MCL_FUTURE)
	    , 0);

  if(g_outfn) {
    ASSERT_TRUE(g_outf = fopen(g_outfn, "w"));
    ASSERT_GE(fprintf(g_outf, "worker.id,loop,period[ms],work[us],jitter[us]\n")
	      , 0);
  }
  Worker worker[] = new Worker[n_worker];

  pthread_t print_thread;
  pthread_attr_t attr;
  struct sched_param sched_param;
  pthread_attr_init(&attr);
  sched_param.sched_priority = sched_get_priority_min(SCHED_OTHER);
  pthread_attr_setschedparam(&attr, &sched_param);
  pthread_create(&print_thread, &attr, printloop, (void*)worker);

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
    ASSERT_EQ(rt_task_start(&worker[i].thread, &workloop, (void*)&worker[i])
	      , 0);
  }

  sleep(duration); /* Sleep for the defined test duration */

  logger.info("Shutting down.");
  bTesting = 0;/* signal the worker threads to exit then wait for them */
  for (i = 0 ; i < n_worker ; ++i) {
    EXPECT_EQ(rt_task_join(&worker[i].thread), 0);
  }
  EXPECT_EQ(pthread_join(print_thread, NULL), 0);

  delete[] worker;
  if(g_outf) {
    fclose(g_outf); g_outf = NULL;
  }
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  RollingFileAppender appender(__FILE__, __FILE__".log"
			       //everything else is default; e.g. 10 MB roll
			       );
  BasicLayout* layout = new BasicLayout();
  appender.setLayout(layout);
  Category& logger = Category::getInstance(__FILE__);
  logger.setAdditivity(false); logger.setAppender(appender);
  logger.setPriority(Priority::INFO);

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
      logger.info("verbosity: %d", g_verbosity);
      break;
    case 'd':
      duration = atoi(optarg);
      logger.info("duration: %d s", duration);
      break;
    case 'w':
      n_worker = atoi(optarg);
      logger.info("worker: %d", n_worker);
      break;
    case 's':
      start_period = atoi(optarg);
      logger.info("start_period: %d ns", start_period);
      break;
    case 'p':
      dec_ppm = atoi(optarg);
      logger.info("dec_ppm: 0.%04d %%", dec_ppm);
      break;
    case 'f':
      g_outfn = optarg;
      logger.info("outfile: %s", g_outfn);
      break;
    case 0: {
      char line[160];
      sprintf(line, "option %s", long_options[option_index].name);
      if(optarg) sprintf(line, " with arg %s", optarg);
      logger.info(line);
    }
      break;
    case '?':/* ambiguous match or extraneous param */
    default:
      logger.error("?? getopt returned character code 0%o ??", c);
      break;
    }
  }
  if (optind < argc) {
    char line[160];
    sprintf(line, "non-option ARGV-elements: ");
    while (optind < argc) sprintf(line, "%s ", argv[optind++]);
    logger.warn(line);
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
    logger.fatal("Invalid argument.  Usage:\n%s", usage);
    return -1;
  }

  int ret = RUN_ALL_TESTS();
  Category::shutdown();
  return ret;
  //} catch(...) {
  //  logger.fatal("Exception");
  //}
}
