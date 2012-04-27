#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <semaphore.h>
#include "timespec.h"
#include "Basic.h"

#ifdef N_CPU
#  if (N_CPU < 0 || N_CPU > 16)
#    error Invalid TEST_DURATION specified; (1, 16) supported.
#  endif
#else
#  warning "N_CPU undefined; defaulting to 1."
#  define N_CPU 1
#endif

#ifdef LOOP_FREQ
#  if (LOOP_FREQ < 1 || LOOP_FREQ > 10000)
#    error "Unsupported LOOP_FREQ"
#  endif
#else
#  warning LOOP_FREQ undefined; defaulting to 1.
#  define LOOP_FREQ 1
#endif
#define PERIOD (1000000000/LOOP_FREQ) /* in nanoseconds */

#ifdef TEST_DURATION
#  if (TEST_DURATION < 0 || TEST_DURATION > 3600)
#    error Unsupported TEST_DURATION specified; (1, 3600) supported.
#  endif
#else
#  warning TEST_DURATION undefined; defaulting to 60.
#  define TEST_DURATION 60
#endif   

struct timespec g_early[N_CPU], g_late[N_CPU];/*g_ for global */

sem_t irqsem;
struct timespec abs_start;
int bTesting = 1;

void *print_code(void *t) { 
  printf("print thread waiting for data...\n");
  while (bTesting) {
    int i;
    
    sem_wait( &irqsem );/* wait for a thread to signal us */
    if(!bTesting) break;

    for ( i = 0 ; i < N_CPU ; i++ ) {
      char searly[TIMESPEC_STRING_LEN], slate[TIMESPEC_STRING_LEN];
      printf("CPU%d: [%s, %s] us, ", i
	     , timespec_toString(&g_early[i], searly, 1E6f, 1)
	     , timespec_toString(&g_late[i], slate, 1E6f, 1));
    } printf("\n");
  }

  printf("print thread exiting...\n");
  return NULL;
}

void *thread_code(void *t) { 
  struct timespec next, cur;
  unsigned char cpu = (unsigned char)t;
  int i;

  next = abs_start;
  timespec_add_ns( next, (PERIOD/N_CPU)*cpu );
  clock_gettime( CLOCK_REALTIME, &cur );
  /* If thread spawning took more time than the desired wakeup time,
     just add multiples of period period */
  while ( timespec_lt( next, cur ) ) timespec_add_ns( next, PERIOD );

  while(bTesting) {
    timespec_add_ns(next, PERIOD);

    clock_nanosleep( CLOCK_REALTIME, TIMER_ABSTIME, &next, NULL);
    if(!bTesting) break;

    clock_gettime( CLOCK_REALTIME, &cur );
    timespec_sub(cur, next);
    {
      //char s[TIMESPEC_STRING_LEN];
      //printf("CPU %d delta: %s\n", cpu, timespec_toString(&cur, s, 1E6f, 1));
    }

    if(timespec_zero(cur)) continue;

    if(timespec_lz(cur)) { /* early! */
      if (timespec_lt(cur, g_early[cpu])) {
	g_early[cpu] = cur;
	sem_post(&irqsem);
      }
    } else { /* if this is later we have seen so far, print it */
      if (timespec_gt(cur, g_late[cpu])) { 
	g_late[cpu] = cur;
	sem_post(&irqsem);
      }
    }
  }

  printf("Worker %d exiting...\n", cpu);
  return NULL;
}

int init_suite() {
  int ok;
   /* initialize the semaphore */
  ok = sem_init( &irqsem, 1, 0 );
  return ok;
}
int clean_suite() { return 0; }

void test1()
{ 
  int i;
  pthread_t thread[N_CPU], print_thread;
  pthread_attr_t attr;
  struct sched_param sched_param;

  printf("DURATION: %d sec\n", TEST_DURATION);
  printf("LOOP_FREQ: %d Hz\n", LOOP_FREQ);

  /* zero the global struct, so the threads don't have to */
  memset(early, sizeof(early), 0); memset(late, sizeof(late), 0);

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
  for ( i = 0; i < N_CPU; i++ ) { 
    /* initialize the thread attributes and set the CPU to run on */
    pthread_attr_init( &attr );
    sched_param.sched_priority = sched_get_priority_max(SCHED_OTHER);
    pthread_attr_setschedparam( &attr, &sched_param );
    pthread_create( &thread[i], &attr, thread_code, (void *)i );
  }

  sleep(TEST_DURATION); /* Sleep for the defined test duration */

  printf("Shutting down...\n");
  bTesting = 0;/* signal the worker threads to exit then wait for them */
  for (i = 0 ; i < N_CPU ; ++i) pthread_join(thread[i], NULL);
  sem_post(&irqsem); pthread_join( print_thread, NULL );
}


/* The main() function for setting up and running the tests.
 * Returns a CUE_SUCCESS on successful running, another
 * CUnit error code on failure.
 */
int main() {
  CU_pSuite pSuite = NULL;

  /* initialize the CUnit test registry */
  if (CUE_SUCCESS != CU_initialize_registry())
    return CU_get_error();

  /* add a suite to the registry */  
  if (!(pSuite = CU_add_suite("jitter_suite", init_suite, clean_suite))) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* add the tests to the suite NOTE - ORDER IS IMPORTANT */
  if (!CU_add_test(pSuite, "test1", test1)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* Run all tests using the console interface */
  CU_basic_set_mode(CU_BRM_VERBOSE);
  CU_basic_run_tests();
  /* finally *****************/
  CU_cleanup_registry();
  return CU_get_error();
}
