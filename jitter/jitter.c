/*
*/
#include <stdio.h>
#include <string.h> /* for memset */
#include <pthread.h>
#include <unistd.h>
#include <semaphore.h>
#include "timespec.h"

#define CPUS_MAX 1
#define num_cpus() (CPUS_MAX)

struct timespec worst[CPUS_MAX];
sem_t irqsem;
struct timespec abs_start;

/* in nanoseconds */
#define PERIOD (1000*1000)

void *print_code(void *t)
{ 
   int i;
   char sworst[TIMESPEC_STRING_LEN];
   while ( 1 ) { 
      sem_wait( &irqsem );/* wait for a thread to signal us */
      for ( i = 0 ; i < num_cpus() ; i++ ) {
         printf("CPU%d: %s us, ", i
		, timespec_toString(&worst[i], sworst, 1E6f, 1));
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
   timespec_add_ns(next, (PERIOD/num_cpus())*cpu );
   clock_gettime( CLOCK_REALTIME, &cur );
   /* If thread spawning took more time than the desired wakeup time,
      just add multiples of period period */
   while ( timespec_lt(next, cur)) timespec_add_ns(next, PERIOD);

   while ( 1 ) { 
      /* set the period so that we're running at PERIOD */
      timespec_add_ns(next, PERIOD);
      /* sleep */
      clock_nanosleep(CLOCK_REALTIME, TIMER_ABSTIME, &next, NULL);
      /* compute the error between now and when
       * we expected to return from the sleep
       */
      clock_gettime( CLOCK_REALTIME, &cur );
      timespec_sub(cur, next);
      /* if this is the first run, set the "late" value */
      if ( !timespec_nz(worst[cpu])) { 
         worst[cpu] = cur;
         sem_post( &irqsem );
      } else { /* if this is the late we have seen so far, print it */
	if ( timespec_lt(worst[cpu], cur) ) { 
	better_be_atomic:
	  worst[cpu] = cur;
	  sem_post( &irqsem );
	}
      } 
   }
   return NULL;
}

void main()
{ 
   int i;
   pthread_attr_t attr;
   struct sched_param sched_param;
   pthread_t thread[CPUS_MAX], print_thread;

   /* zero the global struct, so the threads don't have to */
   memset(worst, sizeof(worst), 0);

   /* initialize the semaphore */
   sem_init( &irqsem, 1, 0 );

   /* get the current time that the threads can base their scheduling on */
   clock_gettime( CLOCK_REALTIME, &abs_start );

   /*
    * Start the thread that prints the timing values.
    * We set the thread priority very low to make sure that it does
    * not interfere with the threads that are doing the actual timing
    */
   pthread_attr_init( &attr );
   sched_param.sched_priority = sched_get_priority_min(SCHED_OTHER);
   pthread_attr_setschedparam( &attr, &sched_param );
   pthread_create( &print_thread, &attr, print_code, (void *)0 );
   
   for ( i = 0; i < num_cpus(); i++ ) { 
      /* initialize the thread attributes and set the CPU to run on
	 (if possible) */
      pthread_attr_init( &attr );
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
   for ( i = 0 ; i < num_cpus() ; i++ )
      pthread_cancel( thread[i] );
   /* cancel the print thread */
   pthread_cancel( print_thread );
#endif

   /* join the threads */
   for ( i = 0 ; i < num_cpus() ; i++ )
      pthread_join( thread[i], NULL );

   /* join the print thread */
   pthread_join( print_thread, NULL );
}
