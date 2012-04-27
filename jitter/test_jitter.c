#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <semaphore.h>
#include <getopt.h>
#include <Basic.h> /* CUnit */
#include <TestDB.h> /* CUnit */
#include "timespec.h"

int verbosity = 0
  , duration = 0
  , n_worker=N_WORKER
  , start_period = 1000000000/LOOP_FREQ, dec_ppm = 0;
#define N_WORKER_MAX 16
struct timespec g_early[N_WORKER_MAX], g_late[N_WORKER_MAX];/*g_ for global */

sem_t irqsem;
struct timespec abs_start;
int bTesting = 1;

void *print_code(void *t) { 
  printf("print thread waiting for data...\n");
  while (bTesting) {
    int i;
    
    sem_wait( &irqsem );/* wait for the worker to signal me */
    if(!bTesting) break;

    for ( i = 0 ; i < n_worker ; i++ ) {
      char searly[TIMESPEC_STRING_LEN], slate[TIMESPEC_STRING_LEN];
      printf("worker %d: [%s, %s] us, ", i
	     , timespec_toString(&g_early[i], searly, 1E6f, 1)
	     , timespec_toString(&g_late[i], slate, 1E6f, 1));
    } printf("\n");
  }

  printf("print thread exiting...\n");
  return NULL;
}

void *worker_code(void *t) { 
  struct timespec next, cur;
  unsigned char worker_id = (unsigned char)t;
  int i = 0 /* loop counter */
    , period = start_period / n_worker;

  next = abs_start;
  timespec_add_ns(next, period*worker_id);
  clock_gettime( CLOCK_REALTIME, &cur );
  /* If thread spawning took more time than the desired wakeup time,
     just add multiples of period period */
  while(timespec_lt(next, cur)) timespec_add_ns(next, period);

  while(bTesting) {
    timespec_add_ns(next, period);

    clock_nanosleep(CLOCK_REALTIME, TIMER_ABSTIME, &next, NULL);
    if(!bTesting) break;

    /* Begin "work" ****************************************/
    clock_gettime(CLOCK_REALTIME, &cur);
    timespec_sub(cur, next);
    {
      //char s[TIMESPEC_STRING_LEN];
      //printf("WORKER %d delta: %s\n", worker_id, timespec_toString(&cur, s, 1E6f, 1));
    }

    if(timespec_nz(cur)) {
      if(timespec_lz(cur)) { /* early! */
	if (timespec_lt(cur, g_early[worker_id])) {
	  g_early[worker_id] = cur;
	  sem_post(&irqsem);
	}
      } else { /* if this is later we have seen so far, print it */
	if (timespec_gt(cur, g_late[worker_id])) { 
	  g_late[worker_id] = cur;
	  sem_post(&irqsem);
	}
      }
    }
    /* decrement the period by a fraction */
    period -= dec_ppm ? period / (1000000 / dec_ppm) : 0;
    if(period < 1000000) break; /* Limit at 1 ms */
    ++i; /* going to log the loop counter */
    /* End "work" ****************************************/
  }

  printf("Worker %d exiting...\n", worker_id);
  return NULL;
}

void test_period_dec() { 
  struct timespec next, cur;
  unsigned char worker_id = 0;
  int i = 0 /* loop counter */
    , period = start_period / n_worker;

  clock_gettime(CLOCK_REALTIME, &next);
  timespec_add_ns(next, period*worker_id);
  clock_gettime(CLOCK_REALTIME, &cur);
  while(timespec_lt(next, cur)) timespec_add_ns(next, period);

  while(period > 1000000) { /* Limit at 1 ms period */
    timespec_add_ns(next, period);
    if(verbosity > 2 && (i % 100) == 0) printf("period[%9d]: %9d\n", i, period);

    /* You would do work here */
    /* decrement the period by a fraction */
    period -= dec_ppm ? period / (1000000 / dec_ppm) : 1;
    CU_ASSERT(++i < 10000000);
  }
}

int init_suite() {
  int ok;
   /* initialize the semaphore */
  ok = sem_init( &irqsem, 1, 0 );
  return ok;
}
int clean_suite() { return 0; }

void test_jitter()
{ 
  int i;
  pthread_t worker_thread[N_WORKER_MAX], print_thread;
  pthread_attr_t attr;
  struct sched_param sched_param;

  /* zero the global struct, so the threads don't have to */
  memset(g_early, sizeof(g_early), 0); memset(g_late, sizeof(g_late), 0);

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
    pthread_create(&worker_thread[i], &attr, worker_code, (void *)i);
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
    "[--start_period=[1000000,1000000000]] [--dec_ppm=[0,1000]]";
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
      verbosity = optarg ? atoi(optarg) : 1;
      printf("verbosity: %d\n", verbosity);
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
  if (!(pSuite = CU_add_suite("jitter_suite", init_suite, clean_suite))) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  if (!CU_ADD_TEST(pSuite, test_period_dec)
      || !CU_ADD_TEST(pSuite, test_jitter)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  CU_basic_set_mode(CU_BRM_VERBOSE);

#ifdef RUN_SEPARTELY
  if((ok = CU_basic_run_test(pSuite, CU_get_test(pSuite, "test_period_dec")))
     != CUE_SUCCESS) {
    fprintf(stderr, "test_period_dec CUnit result: %s\n", CU_get_error_msg());
    goto cleanup;
  }

  if((ok = CU_basic_run_test(pSuite, CU_get_test(pSuite, "test_jitter")))
     != CUE_SUCCESS) {
    fprintf(stderr, "test_jitter CUnit result: %s\n", CU_get_error_msg());
    goto cleanup;
  }
#else
  //CU_console_run_tests();
  CU_basic_run_tests();
#endif

 cleanup:
  CU_cleanup_registry();
  return (ok != CUE_SUCCESS) ? CU_get_error() : ok;
}
