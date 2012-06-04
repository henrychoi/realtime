// system calls ///////////////////////////////////////////
#include <stdio.h>
#include <getopt.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/time.h> /* for getrusage */
//#include <sys/resource.h>
#include <sys/mman.h> /* for mlockall */

// 3rd party stuff ////////////////////////////////////////
#include "gtest/gtest.h"

// my code ////////////////////////////////////////////////
#include "log/log.h"
#include "timespec/timespec.h"
#include "rtds/pipe.h"

struct LoopData { /* the node I am going to shove into q */
  struct timespec deadline, jitter, t_work;
  int period;
  unsigned long long count;
};

class Worker {
 public:
  unsigned char id;
  pthread_t thread;
  Pipe<struct LoopData> loopdata_q, late_q;

  virtual ~Worker() {};
 Worker(size_t loopq_size = 30, size_t lateq_size = 10)
   : loopdata_q(loopq_size), late_q(lateq_size) {};
  virtual void work() {}
};

// globals ////////////////////////////////////////////////
int g_verbosity = 0
  , duration = 0
  , n_worker=N_WORKER
  , start_period = 1000000000/LOOP_FREQ, dec_ppm = 0;

const char* g_outfn = NULL;
FILE* g_outf = NULL;
bool bTesting = 1;
//pid_t g_pid;
struct timespec abs_start;

// functions ////////////////////////////////////////////
void *printloop(void *t) {
  Worker* worker = (Worker*)t;
  log_info("print", "starting.");

  while (bTesting) {
    usleep(10000);//sleep 10 ms, which is a Linux scheduling gradularity

    for(int i = 0; i < n_worker; ++i) {
      struct LoopData loop;

      while(worker[i].loopdata_q.pop(loop)) {
	char line[80];
	char sjitter[TIMESPEC_STRING_LEN], swork[TIMESPEC_STRING_LEN];

	int bts = sprintf(line, "%d,%lld,%.2f,%s,%s\n"
			  , i, loop.count, loop.period/1E6f //[ms]
			  , timespec_toString(&loop.t_work, swork, 1E6f, 1)
			  , timespec_toString(&loop.jitter, sjitter, 1E6f, 1))
	  + 1;

	if(g_outf) fprintf(g_outf, "%s", line);
	if(g_verbosity) printf("%s", line);
      }
    }
  }

  log_info("print", "exiting.");
  return NULL;
}

void *workloop(void *t) {
  Worker* me = (Worker*)t;
  char ctx[8];
  sprintf(ctx, "worker%d", me->id);
  log_info(ctx, "Starting");

  struct LoopData loop;
  loop.count = 0;
  loop.period = start_period / n_worker;
  loop.deadline = abs_start;
  timespec_add_ns(loop.deadline, loop.period*me->id);

  struct timespec now;
  clock_gettime(CLOCK_REALTIME, &now);
  /* If thread spawning took more time than the desired wakeup time,
     just add multiples of period period */
  while(timespec_lt(loop.deadline, now)) {
    timespec_add_ns(loop.deadline, loop.period);
  }
  while(bTesting) {
    clock_nanosleep(CLOCK_REALTIME, TIMER_ABSTIME, &loop.deadline, NULL);
    if(!bTesting) break;

    clock_gettime(CLOCK_REALTIME, &now); /* jitter = now - next */
    loop.jitter = now; timespec_sub(loop.jitter, loop.deadline);

    /* Begin "work" ****************************************/
    me->work();
    /* End "work" ******************************************/
    struct timespec t0 = now;//back up to a easy to remember var
    clock_gettime(CLOCK_REALTIME, &now);

    // Post work book keeping ///////////////////////////////
    //to report how much the work took
    loop.t_work = now; timespec_sub(loop.t_work, t0);
    if(me->loopdata_q.push(loop)) {
    } else { /* Have to throw away data; need to alarm! */
      log_alert(ctx, "Loop data full");
    }

    if(!me->late_q.isEmpty() // Manage the late q
       && me->late_q[0].count < (loop.count - 100)) {
      me->late_q.pop(); // if sufficiently old, forget about it
    }
    timespec_add_ns(loop.deadline, loop.period);
    if(timespec_gt(now, loop.deadline)) { // Did I miss the deadline?
      // How badly did I miss the deadline?
      // Definition of "badness": just a simple count over the past N loop
      if(me->late_q.isFull()) { //FATAL
	log_info(ctx, "Missed too many deadlines");
	break;
      }
    }

    /* decrement the period by a fraction */
    loop.period -= dec_ppm ? loop.period / (1000000 / dec_ppm) : 0;
    if(loop.period < 1000000) break; /* Limit at 1 ms for now */
    ++loop.count;
  }

  log_info(ctx, "Exiting");
  return NULL;
}

TEST(LoopTest, DecrementPeriod) { 
  struct timespec next, cur;
  unsigned char worker_id = 0;
  int i = 0 /* loop counter */
    , period = start_period / n_worker;
  char msg[100];

  if(dec_ppm <= 0) {
    return;
  }
  clock_gettime(CLOCK_REALTIME, &next);
  timespec_add_ns(next, period*worker_id);
  clock_gettime(CLOCK_REALTIME, &cur);
  while(timespec_lt(next, cur)) timespec_add_ns(next, period);

  while(period > 1000000) { /* Limit at 1 ms period */
    timespec_add_ns(next, period);
    if(g_verbosity > 2 && (i % 100) == 0) {
      sprintf(msg, "period[%9d]: %9d", i, period);
      log_debug("DecrementPeriod", msg);
    }

    /* You would do work here */
    /* decrement the period by a fraction */
    period -= dec_ppm ? period / (1000000 / dec_ppm) : 1;
    EXPECT_LT(++i, 10000000);
  }
}

TEST(JitterTest, Loop) { 
  int i;

  //g_pid = getpid();

  /* Avoids memory swapping for this program */
  ASSERT_EQ(mlockall(MCL_CURRENT|MCL_FUTURE), 0);

  if(g_outfn) {
    ASSERT_TRUE(g_outf = fopen(g_outfn, "w"));
    ASSERT_GE(fprintf(g_outf, "worker_id,loop,period[ms],work[us],jitter[us]\n")
	      , 0);
  }
  Worker* worker = new Worker[n_worker];

  /*
   * Start the thread that prints the timing values.
   * We set the thread priority very low to make sure that it does
   * not interfere with the threads that are doing the actual timing
   * From 'man sched_setscheduler':
   For processes scheduled under one of the normal scheduling policies
   (SCHED_OTHER, SCHED_IDLE, SCHED_BATCH), sched_priority is not used in
   scheduling decisions (it must be specified as 0).
   */
  pthread_t print_thread;
  pthread_attr_t attr;
  struct sched_param sched_param;
  pthread_attr_init(&attr);
  ASSERT_EQ(pthread_attr_setschedpolicy(&attr, SCHED_FIFO), 0);
  sched_param.sched_priority = sched_get_priority_min(SCHED_FIFO);
  /* sched_param.sched_priority = sched_get_priority_min(SCHED_OTHER); */
  pthread_attr_setschedparam( &attr, &sched_param );
  pthread_create(&print_thread, &attr, printloop, (void*)worker);
  
  /* get the current time that the threads can base their scheduling on */
  clock_gettime( CLOCK_REALTIME, &abs_start );

  /* create the threads to do the timing */
  for ( i = 0; i < n_worker; i++ ) { 
    /* initialize the thread attributes and set the WORKER to run on */
    pthread_attr_init( &attr );
    ASSERT_EQ(pthread_attr_setschedpolicy(&attr, SCHED_FIFO), 0);
    sched_param.sched_priority = sched_get_priority_min(SCHED_FIFO) + 1;
    pthread_attr_setschedparam( &attr, &sched_param );
    pthread_create(&worker[i].thread, &attr, workloop, (void*)&worker[i]);
  }

  sleep(duration); /* Sleep for the defined test duration */

  log_info("main", "Shutting down.");
  bTesting = 0;/* signal the worker threads to exit then wait for them */
  for(i = 0 ; i < n_worker ; ++i) {
    EXPECT_EQ(pthread_join(worker[i].thread, NULL), 0);
  }
  EXPECT_EQ(pthread_join(print_thread, NULL), 0);

  delete[] worker;
  if(g_outf) {
    fclose(g_outf); g_outf = NULL;
  }
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  const char* usage =
    "--duration=(10,3600]\n"
    "[--n_worker=[1,16]]\n"
    "[--start_period=[1000000,1000000000]] [--dec_ppm=[0,1000]]\n"
    "[--outfile=<CSV file to record the result>]\n"
    "[--verbosity=[0,2]]\n";
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
  const char* ctx = "main";
  char msg[100];

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
      sprintf(msg, "verbosity: %d", g_verbosity);
      log_info(ctx, msg);
      break;
    case 'd':
      duration = atoi(optarg);
      sprintf(msg, "duration: %d s", duration);
      log_info(ctx, msg);
      break;
    case 'w':
      n_worker = atoi(optarg);
      sprintf(msg, "worker: %d", n_worker);
      log_info(ctx, msg);
      break;
    case 's':
      start_period = atoi(optarg);
      sprintf(msg, "start_period: %d ns", start_period);
      log_info(ctx, msg);
      break;
    case 'p':
      dec_ppm = atoi(optarg);
      sprintf(msg, "dec_ppm: 0.%04d %%", dec_ppm);
      log_info(ctx, msg);
      break;
    case 'f':
      g_outfn = optarg;
      sprintf("outfile: %s", g_outfn);
      log_info(ctx, msg);
      break;
    case 0:
      sprintf(msg, "option %s", long_options[option_index].name);
      if(optarg) sprintf(msg, " with arg %s", optarg);
      log_info(ctx, msg);
      break;
    case '?':/* ambiguous match or extraneous param */
    default:
      sprintf(msg, "?? getopt returned character code 0%o ??", c);
      log_error(ctx, msg);
      break;
    }
  }
  if (optind < argc) {
    sprintf(msg, "non-option ARGV-elements: ");
    while (optind < argc) sprintf(msg, "%s ", argv[optind++]);
    log_warn(ctx, msg);
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
    log_fatal("Invalid argument.  Usage:\n%s", usage);
    return -1;
  }

  return RUN_ALL_TESTS();
}
