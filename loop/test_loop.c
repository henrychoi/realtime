#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <semaphore.h>
#include <getopt.h>
#include <sys/resource.h>
#include <Basic.h> /* CUnit */
#include <TestDB.h> /* CUnit */
#include "timespec.h"
#include "llsMQ.h"
#include "loop.h"

#define LOOP_FREQ 100
int g_verbosity = 0
  , duration = 0
  , n_worker=1
  , start_period = 1000000000/LOOP_FREQ, dec_ppm = 0;
const char* g_outfn = NULL;
FILE* g_outf = NULL;
#define N_WORKER_MAX 4

struct Worker g_worker[N_WORKER_MAX];

struct LoopData { /* the node I am going to shove into q */
  struct timespec jitter, t_work;
  int count;
  int period;
};

sem_t irqsem;
struct timespec abs_start;
unsigned char bTesting = 1;

void *print_code(void *t) {
  printf("print thread waiting for data...\n");

  while (bTesting) {
    int i;
    
    sem_wait( &irqsem );/* wait for the worker to signal me */
    if(!bTesting) break;

    /* Don't know which worker signalled me; have to check all of them;
       a select() on different semaphores would be doing essentially the
       same thing.  WaitForMultipleObjects() is nice in this regard.
    */
    for(i = 0; i < n_worker; ++i) {
      struct LoopData loop;
      struct rusage ru;
      char sjitter[TIMESPEC_STRING_LEN], swork[TIMESPEC_STRING_LEN];

      if(!llsMQ_pop(&g_worker[i].q, &loop))
	continue;

      getrusage(RUSAGE_SELF, &ru);/* I should do something with this */

      if(g_outf) {
	fprintf(g_outf, "%d,%d,%d,%s,%s\n"
		, i, loop.count, loop.period
		, timespec_toString(&loop.t_work, swork, 1E6f, 1)
		, timespec_toString(&loop.jitter, sjitter, 1E6f, 1));
      }
    }
  }

  printf("print thread exiting...\n");
  return NULL;
}

void *start_worker(void *t) {
  struct Worker* worker = (struct Worker*)t;
  struct LoopData loop;
  struct timespec next, cur;
  unsigned char worker_id = (unsigned char)t;
  printf("Worker %d starting...\n", worker->id);

  loop.count = 0;
  loop.period = start_period / n_worker;

  next = abs_start;
  timespec_add_ns(next, loop.period*worker_id);
  clock_gettime(CLOCK_REALTIME, &cur);
  /* If thread spawning took more time than the desired wakeup time,
     just add multiples of period period */
  while(timespec_lt(next, cur)) timespec_add_ns(next, loop.period);

  while(bTesting) {
    struct timespec t0;
    timespec_add_ns(next, loop.period);

    clock_nanosleep(CLOCK_REALTIME, TIMER_ABSTIME, &next, NULL);
    if(!bTesting) break;

    clock_gettime(CLOCK_REALTIME, &t0); /* jitter = now - next */
    /* Begin "work" ****************************************/
    loop.jitter = t0; timespec_sub(loop.jitter, next); /* measure jitter */
    if(worker->work) worker->work(NULL);
    /* End "work" ******************************************/
    clock_gettime(CLOCK_REALTIME, &loop.t_work); timespec_sub(loop.t_work, t0);

    if(llsMQ_push(&worker->q, &loop)) {
      sem_post(&irqsem);
    } else { /* Have to throw away data; need to alarm! */
    }
    /* decrement the period by a fraction */
    loop.period -= dec_ppm ? loop.period / (1000000 / dec_ppm) : 0;
    if(loop.period < 1000000) break; /* Limit at 1 ms */
    ++loop.count;
  }

  printf("Worker %d exiting...\n", worker_id);
  return NULL;
}

int init_suite() {
  int err = 0;
  memset(g_worker, sizeof(*g_worker), 0);
  if(!err && g_outfn
     && !(g_outf = fopen(g_outfn, "w"))) {
    err = errno;
  }
  if(!err) err = sem_init(&irqsem, 1, 0);
  if(!err) {
    int i;
    for(i = 0; i < n_worker; ++i) {
      if(!llsMQ_alloc(&g_worker[i].q, 3, sizeof(struct LoopData))) {
	err = 1;
      }
    }
  }
  return err;
}
int clean_suite() {
  int err = 0;
  int i;
  for(i = 0; i < n_worker; ++i) {
    llsMQ_free(&g_worker[i].q);
  }
  err = sem_destroy(&irqsem);
  if(g_outf) {
    fclose(g_outf); g_outf = NULL;
  }
  return err;
}

void test_loop()
{ 
  int i;
  pthread_t worker_thread[N_WORKER_MAX], print_thread;
  pthread_attr_t attr;
  struct sched_param sched_param;

  /*
   * Start the thread that prints the timing values.
   * We set the thread priority very low to make sure that it does
   * not interfere with the threads that are doing the actual timing
   */
  pthread_attr_init( &attr );
  sched_param.sched_priority = sched_get_priority_min(SCHED_OTHER);
  pthread_attr_setschedparam( &attr, &sched_param );
  pthread_create( &print_thread, &attr, print_code, (void *)0 );
  
  /* get the current time that the threads can base their scheduling on */
  clock_gettime( CLOCK_REALTIME, &abs_start );

  /* create the threads to do the timing */
  for ( i = 0; i < n_worker; i++ ) { 
    /* initialize the thread attributes and set the WORKER to run on */
    pthread_attr_init( &attr );
    sched_param.sched_priority = sched_get_priority_max(SCHED_OTHER);
    pthread_attr_setschedparam( &attr, &sched_param );
    pthread_create(&worker_thread[i], &attr, start_worker, &g_worker[i]);
  }

  sleep(duration); /* Sleep for the defined test duration */

  printf("Shutting down...\n");
  bTesting = 0;/* signal the worker threads to exit then wait for them */
  for (i = 0 ; i < n_worker ; ++i) pthread_join(worker_thread[i], NULL);
  sem_post(&irqsem); pthread_join( print_thread, NULL );
}

/* The main() function for setting up and running the tests.
 * Returns a CUE_SUCCESS on successful running, another
 * CUnit error code on failure.
 */
int main(int argc, char* argv[]) {
  CU_pSuite pSuite = NULL;
  CU_ErrorCode ok = CUE_SUCCESS;

  const char* usage =
    "--duration=(10,3600]\n"
    "[--n_worker=[1,16]]\n"
    "[--start_period=[1000000,1000000000]] [--dec_ppm=[0,1000]]\n"
    "[--outfile=<CSV file to record the result>]";
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

  /* initialize the CUnit test registry */
  if (CUE_SUCCESS != CU_initialize_registry())
    return CU_get_error();

  /* add a suite to the registry */  
  if (!(pSuite = CU_add_suite("loop_suite", init_suite, clean_suite))) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  if (!CU_ADD_TEST(pSuite, test_loop)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  CU_basic_set_mode(CU_BRM_VERBOSE);
  CU_basic_run_tests();

 cleanup:
  CU_cleanup_registry();
  return (ok != CUE_SUCCESS) ? CU_get_error() : ok;
}
