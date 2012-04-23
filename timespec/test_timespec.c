#include "Basic.h"
#include "timespec.h"

int init_suite() { return 0; }
int clean_suite() { return 0; }
void test_sub() {
  struct timespec time = TIMESPEC_ZERO;
}
void test_toString() {
   char s[TIMESPEC_STRING_LEN];
   struct timespec time = TIMESPEC_ZERO;
#if 0
   printf("TIMESPEC_ZERO = %s s\n", timespec_toString(&time, s, 1.0f, 3));
   printf("TIMESPEC_ZERO = %s ms\n", timespec_toString(&time, s, 1E3f, 1));
   printf("TIMESPEC_ZERO = %s us\n", timespec_toString(&time, s, 1E6f, 1));

   time = TIMESPEC_ONESEC;
   printf("TIMESPEC_ONESEC = %s s\n", timespec_toString(&time, s, 1.0f, 3));
   printf("TIMESPEC_ONESEC = %s ms\n", timespec_toString(&time, s, 1E3f, 1));
   printf("TIMESPEC_ONESEC = %s us\n", timespec_toString(&time, s, 1E6f, 1));

   timespec_sub(&time, &TIMESPEC_ONESEC);
   printf("-1 s = %s ns\n", timespec_toString(&time, s, 1.0f, 3);

   time = TIMESPEC_ZERO;
   timespec_sub(&time, &TIMESPEC_NANOSEC);
   printf("-1 ns = %s ns\n", timespec_toString(&time, s, 1E9f, 0);
#endif
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
  pSuite = CU_add_suite("timespec_suite", init_suite, clean_suite);
  if (NULL == pSuite) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* add the tests to the suite */
  /* NOTE - ORDER IS IMPORTANT - MUST TEST fread() AFTER fprintf() */
  if (!CU_add_test(pSuite, "test_sub", test_sub)
      || !CU_add_test(pSuite, "test_toString", test_toString)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* Run all tests using the console interface */
  CU_basic_set_mode(CU_BRM_VERBOSE);
  CU_basic_run_tests();
  CU_cleanup_registry();
  return CU_get_error();
}
