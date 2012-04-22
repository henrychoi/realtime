/*
*/
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <semaphore.h>
#include "timespec.h"


#ifndef CONFIG_RTL
#define RTL_CPUS_MAX 1
#define rtl_num_cpus() (RTL_CPUS_MAX)
#endif //ndef CONFIG_RTL

pthread_t thread[RTL_CPUS_MAX], print_thread;
struct timespec early[RTL_CPUS_MAX],  late[RTL_CPUS_MAX];
sem_t irqsem;
struct timespec abs_start;

/* in nanoseconds */
#define PERIOD (1000*1000)

void *print_code(void *t)
{ 
   int i;
   char searly[TIMESPEC_STRING_LEN], slate[TIMESPEC_STRING_LEN];
   while ( 1 ) { 
      /* wait for a thread to signal us */
      sem_wait( &irqsem );
      for ( i = 0 ; i < rtl_num_cpus() ; i++ ) {
         printf("CPU%d: [%s, %s] us, ", i
		, timespec_toString(&early[i], searly, 1E6f, 1)
		, timespec_toString(&late[i], slate, 1E6f, 1));
      } printf("\n");
   }
   return NULL;
}

void *thread_code(void *t)
{ 
   struct timespec next, cur;
   unsigned char cpu = (unsigned char)t;

   /* Get the current time and the start time that the main() function
    * setup for us so that all the threads are synchronized. Then, add
    * a per-cpu skew to them so the threads don't end up becoming runnable
    * at the same time and creating unnecessary resource contention.
    */
   next = abs_start;
   timespec_add_ns( &next, (PERIOD/rtl_num_cpus())*cpu );
   clock_gettime( CLOCK_REALTIME, &cur );
   /* If thread spawning took more time than the desired wakeup time,
      just add multiples of period period */
   while ( timespec_lt( &next, &cur ) ) timespec_add_ns( &next, PERIOD );

   while ( 1 ) { 
      /* set the period so that we're running at PERIOD */
      timespec_add_ns( &next, PERIOD );
      /* sleep */
      clock_nanosleep( CLOCK_REALTIME, TIMER_ABSTIME, &next, NULL);
      /* compute the error between now and when
       * we expected to return from the sleep
       */
      clock_gettime( CLOCK_REALTIME, &cur );
      timespec_sub( &cur, &next );
      /* if this is the first run, set the "late" value */
      if ( !timespec_nz(&late[cpu]) ) { 
         late[cpu] = cur;
         sem_post( &irqsem );
      } else { /* if this is the late we have seen so far, print it */
	if ( timespec_lt( &late[cpu], &cur ) ) { 
	  late[cpu] = cur;
	  sem_post( &irqsem );
	}
      } 
   }
   return NULL;
}

void test_jitter()
{ 
   int i;
   pthread_attr_t attr;
   struct sched_param sched_param;

   /* zero the global struct, so the threads don't have to */
   memset(early, sizeof(early), 0);
   memset(late, sizeof(late), 0);

   /* initialize the semaphore */
   sem_init( &irqsem, 1, 0 );

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

#ifdef CONFIG_RTL
      /* Linux does not allow us to set the CPU to run on */
      pthread_attr_setcpu_np( &attr, i );
#endif

      sched_param.sched_priority = sched_get_priority_max(SCHED_OTHER);
      pthread_attr_setschedparam( &attr, &sched_param );
      pthread_create( &thread[i], &attr, thread_code, (void *)i );
   }

   /* wait for the thread to exit or for the user
    * to signal us asynchronously (with ^c or some such) to exit.
    */
#ifdef CONFIG_RTL
   rtl_main_wait();

   /* cancel the threads */
   for ( i = 0 ; i < rtl_num_cpus() ; i++ )
      pthread_cancel( thread[i] );
   /* cancel the print thread */
   pthread_cancel( print_thread );
#endif

   /* join the threads */
   for ( i = 0 ; i < rtl_num_cpus() ; i++ )
      pthread_join( thread[i], NULL );

   /* join the print thread */
   pthread_join( print_thread, NULL );
}
