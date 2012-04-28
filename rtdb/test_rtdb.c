#include <Basic.h>
#include <TestDB.h>
#include "llsQ.h"
#include "llsMP.h"

int init_suite() { return 0; }
int clean_suite() { return 0; }

/* Test fundamental assumptions made by the memory pool */
void test_llsMP_dependency() {
  CU_ASSERT_EQUAL(llsMP_align_size(sizeof(int), sizeof(int)), sizeof(int));
}

void test_llsQ_1() {
}

#define CU_TEST_NAME_FUNC(x) {#x, x}

/* The main() function for setting up and running the tests.
 * Returns a CUE_SUCCESS on successful running, another
 * CUnit error code on failure.
 */
int main() {
  CU_pSuite pSuite = NULL;
  CU_TestInfo a_llsQ_test[] = {
    CU_TEST_NAME_FUNC(test_llsQ_1),
    CU_TEST_INFO_NULL,};
  CU_TestInfo a_llsMP_test[] = {
    CU_TEST_NAME_FUNC(test_llsMP_dependency),
    CU_TEST_INFO_NULL,};
  CU_SuiteInfo suites[] = {
    { "llsMP", init_suite, clean_suite, a_llsMP_test },
    { "llsQ", init_suite, clean_suite, a_llsQ_test },
    CU_SUITE_INFO_NULL,
  };

  /* initialize the CUnit test registry */
  if (CUE_SUCCESS != CU_initialize_registry())
    return CU_get_error();

  /* add a suite to the registry */  
  if (!CU_register_suites(suites)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* Run all tests using the console interface */
  CU_basic_set_mode(CU_BRM_NORMAL);
  CU_basic_run_tests();
  CU_cleanup_registry();
  return CU_get_error();
}
