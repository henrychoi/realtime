#include <stdio.h>
#include <string.h> /* for memcpy */
#include <pthread.h>
#include <unistd.h>
#include <semaphore.h>
#include "timespec.h"
#include "Basic.h"

#define RTL_CPUS_MAX 1
#define rtl_num_cpus() (RTL_CPUS_MAX)

#ifdef LOOP_FREQ
#  if (LOOP_FREQ < 1 || LOOP_FREQ > 1000)
#    error "Unsupported LOOP_FREQ"
#  endif
#else /* otherwise, use default value */
#  warning "LOOP_FREQ undefined; defaulting to 1."
#  define LOOP_FREQ 1
#endif
#define PERIOD (1000000000/LOOP_FREQ) /* in nanoseconds */

#ifdef TEST_DURATION /* if specified, validity check */
#  if (TEST_DURATION < 0 || TEST_DURATION > 3600)
#    error Invalid TEST_DURATION specified; (1, 3600) required.
#  endif
#else
#  warning "TEST_DURATION is undefined; defaulting to 60."
#  define TEST_DURATION 60
#endif   

#define USE_TIMESPEC
#ifdef USE_TIMESPEC
struct timespec early[RTL_CPUS_MAX],  late[RTL_CPUS_MAX];
#else
unsigned long long gu64a_early[RTL_CPUS_MAX], gu64a_late[RTL_CPUS_MAX];
#endif

sem_t irqsem;
struct timespec abs_start;
int bTesting = 1;

void *print_code(void *t)
{ 
   int i;
   char searly[TIMESPEC_STRING_LEN], slate[TIMESPEC_STRING_LEN];
   printf("Waiting for data...\n");
   while (bTesting) {
      /* wait for a thread to signal us */
      sem_wait( &irqsem );
      if(!bTesting) break;

      for ( i = 0 ; i < rtl_num_cpus() ; i++ ) {
#ifdef USE_TIMESPEC
	printf("CPU%d: [%s, %s] us, ", i
	       , timespec_toString(&early[i], searly, 1E6f, 1)
	       , timespec_toString(&late[i], slate, 1E6f, 1));
#else
	struct timespec early, late;
	unsigned long long u64_early = gu64a_early[i], u64_late = gu64a_late[i];
	memcpy(&early, u64_early, sizeof(u64_early))
	printf("CPU%d: [%s, %s] us, ", i
	       , timespec_toString(&early, searly, 1E6f, 1)
	       , timespec_toString(&late, slate, 1E6f, 1));
#endif
      } printf("\n");
   }

   printf("Exiting print_code...\n");
   return NULL;
}

void *thread_code(void *t)
{ 
   struct timespec next, cur;
   unsigned char cpu = (unsigned char)t;
   int i;

   /* Get the current time and the start time that the main() function
    * setup for us so that all the threads are synchronized. Then, add
    * a per-cpu skew to them so the threads don't end up becoming runnable
    * at the same time and creating unnecessary resource contention.
    */
   next = abs_start;

   timespec_add_ns( next, (PERIOD/rtl_num_cpus())*cpu );
   clock_gettime( CLOCK_REALTIME, &cur );
   /* If thread spawning took more time than the desired wakeup time,
      just add multiples of period period */
   while ( timespec_lt( next, cur ) ) timespec_add_ns( next, PERIOD );

   while(bTesting) {
     char s[TIMESPEC_STRING_LEN];

     /* set the period so that we're running at PERIOD */
     timespec_add_ns(next, PERIOD);

     clock_nanosleep( CLOCK_REALTIME, TIMER_ABSTIME, &next, NULL);
     if(!bTesting) break;

     /* compute the error between now and when
      * we expected to return from the sleep
      */
     clock_gettime( CLOCK_REALTIME, &cur );
     timespec_sub(cur, next);
     //printf("CPU %d delta: %s\n", cpu, timespec_toString(&cur, s, 1E6f, 1));

     if(timespec_nz(cur)) {
       if(timespec_lz(cur)) { /* early! */
	 if (timespec_lt(cur, early[cpu])) {
	   early[cpu] = cur;
	   sem_post(&irqsem);
	 }
       } else { /* if this is later we have seen so far, print it */
	 if (timespec_gt(cur, late[cpu])) { 
	   late[cpu] = cur;
	   sem_post(&irqsem);
	 }
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
   pthread_t thread[RTL_CPUS_MAX], print_thread;
   pthread_attr_t attr;
   struct sched_param sched_param;

   printf("DURATION: %d sec\n", TEST_DURATION);
   printf("LOOP_FREQ: %d Hz\n", LOOP_FREQ);

   /* zero the global struct, so the threads don't have to */
   memset(early, sizeof(early), 0);
   memset(late, sizeof(late), 0);

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
   for ( i = 0; i < rtl_num_cpus(); i++ ) { 
      /* initialize the thread attributes and set the CPU to run on */
      pthread_attr_init( &attr );

      sched_param.sched_priority = sched_get_priority_max(SCHED_OTHER);
      pthread_attr_setschedparam( &attr, &sched_param );
      pthread_create( &thread[i], &attr, thread_code, (void *)i );
   }

   /* Sleep for the defined test duration */
   sleep(TEST_DURATION);

   printf("Shutting down...\n");

   bTesting = 0;/* signal the worker threads to exit */
   /* join the threads */
   for ( i = 0 ; i < rtl_num_cpus() ; i++ )
      pthread_join( thread[i], NULL );

   sem_post(&irqsem);
   /* join the print thread */
   pthread_join( print_thread, NULL );
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
