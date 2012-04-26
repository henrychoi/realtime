#include <string.h> /* for memcpy */
#include "Basic.h"
#include "timespec.h"

int init_suite() { return 0; }
int clean_suite() { return 0; }

/* Test fundamental assumptions */
void test_types() {
  struct timespec t1 = {0x12345678, 12345678}, t2;
  long long u64t1, u64t2;

  CU_ASSERT_EQUAL(sizeof(u64t1), 8);
  CU_ASSERT_EQUAL(sizeof(t1), 8);

  memcpy(&u64t1, &t1, sizeof(u64t1));
  CU_ASSERT_EQUAL(memcmp(&u64t1, &t1, sizeof(u64t1)), 0);

  u64t2 = u64t1;
  CU_ASSERT_EQUAL(u64t1, u64t2);

  memcpy(&t2, &u64t2, sizeof(u64t2));
  CU_ASSERT_EQUAL(memcmp(&t2, &u64t2, sizeof(u64t2)), 0);

  CU_ASSERT_TRUE(timespec_equal(t1, t2));
}

void test_arithmetic() {
  struct timespec time, t1, t2;
  time = TIMESPEC_ZERO; t1 = TIMESPEC_ZERO;
  timespec_sub(time, t1);
  CU_ASSERT_FALSE(timespec_nz(time));

  time = TIMESPEC_ZERO; t1 = TIMESPEC_NANOSEC;
  timespec_sub(time, t1);
  timespec_add_ns(time, 1);
  CU_ASSERT_FALSE(timespec_nz(time));

  time = TIMESPEC_ZERO; t1 = TIMESPEC_NANOSEC, t2 = TIMESPEC_MICROSEC;
  timespec_add_ns(time, 1001);
  timespec_sub(time, t1);
  CU_ASSERT_TRUE(timespec_equal(time, t2));
}
void test_toString() {
   char s[TIMESPEC_STRING_LEN];
   struct timespec time;

   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_ZERO,s,1.f, 0), "0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_ZERO,s,1.f, 1), "0.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_ZERO,s,1000.f, 1), "0.0");

   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_SEC,s,1.f, 0), "1");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_SEC,s,1.f, 1), "1.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_SEC,s,1000.f,1), "1000.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_SEC,s,.001f, 1), "0.0");

   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 0), "0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 1), "0.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 2), "0.00");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 3), "0.001");

   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1E1f, 1), "0.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1E2f, 1), "0.1");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1E3f, 1), "1.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1E3f, 0), "1");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_MILLISEC,s, 1E3f, 2), "1.00");

   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_NANOSEC,s, 1E0f, 0), "0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_NANOSEC,s, 1E0f, 1), "0.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_NANOSEC,s, 1E8f, 1), "0.1");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_NANOSEC,s, 1E9f, 0), "1");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&TIMESPEC_NANOSEC,s, 1E9f, 1), "1.0");

   time = TIMESPEC_ZERO; timespec_sub(time, TIMESPEC_NANOSEC);
   CU_ASSERT_STRING_EQUAL(timespec_toString(&time, s, 1E9f, 0), "-1");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&time, s, 1E9f, 1), "-1.0");

   time = TIMESPEC_ZERO; timespec_sub(time, TIMESPEC_MICROSEC);
   CU_ASSERT_STRING_EQUAL(timespec_toString(&time, s, 1E6f, 0), "-1");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&time, s, 1E6f, 1), "-1.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&time, s, 1E9f, 1), "-1000.0");
   CU_ASSERT_STRING_EQUAL(timespec_toString(&time, s, 1E3f, 3), "-0.001");

   CU_ASSERT_EQUAL(printf("%s", timespec_toString(&time, s, 1E3f, 3)),
		   strlen("-0.001"));
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
  if (!(pSuite = CU_add_suite("timespec_suite", init_suite, clean_suite))) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* add the tests to the suite NOTE - ORDER IS IMPORTANT */
  if (!CU_add_test(pSuite, "test_types", test_types)
      || !CU_add_test(pSuite, "test_arithmetic", test_arithmetic)
      || !CU_add_test(pSuite, "test_toString", test_toString)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* Run all tests using the console interface */
  CU_basic_set_mode(CU_BRM_NORMAL);
  CU_basic_run_tests();
  CU_cleanup_registry();
  return CU_get_error();
}
