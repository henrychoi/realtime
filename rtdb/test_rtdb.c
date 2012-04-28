#include <time.h> /* for struct timespec */
#include <Basic.h>
#include "llsQ.h"
#include "llsMP.h"

int init_suite() { return 0; }
int clean_suite() { return 0; }

struct MyStruct {
  char ca, cb;
  struct timespec early, late;
  short sa, sb;
  int ia;
  long la;
  long long lla;
};

/* Test fundamental assumptions made by the memory pool */
void llsMP_testSingleThread() {
  llsMP s,/* build one on the stack */
    *h; /* and this is for the heap */
  int* intp1, *intp2;
  char* cp1, *cp2;
  long long *llp1, *llp2;
  struct timespec* tsp1, *tsp2;
  struct MyStruct* msp1, *msp2;

  CU_ASSERT(llsMP_alloc(&s, 1, sizeof(char), sizeof(char)));
  CU_ASSERT_EQUAL(s._available, 1);
  CU_ASSERT_PTR_NOT_NULL(cp1 = (char*)llsMP_get(&s));
  CU_ASSERT_EQUAL(s._available, 0);
  *cp1 = 'h';
  CU_ASSERT_PTR_NULL(llsMP_get(&s));
  CU_ASSERT(llsMP_return(&s, cp1));
  CU_ASSERT_FALSE(llsMP_return(&s, cp1));
  CU_ASSERT_PTR_NOT_NULL(cp2 = (char*)llsMP_get(&s));
  CU_ASSERT_PTR_EQUAL(cp1, cp2);
  CU_ASSERT_EQUAL(*cp2, 'h');
  llsMP_free(&s);

  CU_ASSERT(llsMP_alloc(&s, 2, sizeof(char), sizeof(char)));
  CU_ASSERT_PTR_NOT_NULL(cp1 = (char*)llsMP_get(&s));
  CU_ASSERT_PTR_NOT_NULL(cp2 = (char*)llsMP_get(&s));
  CU_ASSERT_PTR_EQUAL(cp1 - cp2, sizeof(char));
  llsMP_free(&s);

  CU_ASSERT(llsMP_alloc(&s, 2, sizeof(int), sizeof(int)));
  CU_ASSERT_FALSE(llsMP_return(&s, NULL));
  CU_ASSERT_PTR_NOT_NULL(intp1 = (int*)llsMP_get(&s));
  CU_ASSERT_PTR_NOT_NULL(intp2 = (int*)llsMP_get(&s));
  CU_ASSERT_PTR_EQUAL(intp1 - intp2, 1); /* pointer arithmetic */
  CU_ASSERT_PTR_EQUAL((size_t)intp1 - (size_t)intp2, sizeof(int));
  CU_ASSERT_EQUAL(*intp1 = 1234, 1234);
  CU_ASSERT_PTR_NULL(llsMP_get(&s));
  CU_ASSERT_TRUE(llsMP_return(&s, intp1));
  CU_ASSERT_TRUE(llsMP_return(&s, intp2));
  CU_ASSERT_FALSE(llsMP_return(&s, intp1));
  llsMP_free(&s);

  CU_ASSERT(llsMP_alloc(&s, 3, sizeof(long long), sizeof(long long)));
  CU_ASSERT_FALSE(llsMP_return(&s, NULL));
  CU_ASSERT_PTR_NOT_NULL(llp1 = (long long*)llsMP_get(&s));
  CU_ASSERT_PTR_NOT_NULL(llp2 = (long long*)llsMP_get(&s));
  CU_ASSERT_PTR_EQUAL(llp1 - llp2, 1); /* pointer arithmetic */
  CU_ASSERT_PTR_EQUAL((size_t)llp1 - (size_t)llp2, sizeof(long long));
  CU_ASSERT_EQUAL(*llp1 = 1234, 1234);
  CU_ASSERT_TRUE(llsMP_return(&s, llp1));
  CU_ASSERT_TRUE(llsMP_return(&s, llp2));
  CU_ASSERT_EQUAL(s._available, 3);
  llsMP_free(&s);

}

void llsQ_test0() {
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

  if (!(pSuite = CU_add_suite("llsMP", init_suite, clean_suite))) {
    CU_cleanup_registry();
    return CU_get_error();
  }
  if (!CU_add_test(pSuite, "llsMP_testSingleThread", llsMP_testSingleThread)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* Run all tests using the console interface */
  CU_basic_set_mode(CU_BRM_NORMAL);
  CU_basic_run_tests();
  CU_cleanup_registry();
  return CU_get_error();
}
