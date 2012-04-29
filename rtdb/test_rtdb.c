#include <time.h> /* for struct timespec */
#include <Basic.h>
#include "llsQ.h"
#include "llsMP.h"
#include "llsMQ.h"

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

void llsMP_testAlignment() {
  CU_ASSERT_EQUAL(alignmentof(char), sizeof(char));
  CU_ASSERT_EQUAL(alignmentof(void*), sizeof(void*));
  CU_ASSERT_EQUAL(alignmentof(short), sizeof(short));  
  CU_ASSERT_EQUAL(alignmentof(int), sizeof(int));
  CU_ASSERT(alignmentof(long long) >= alignmentof(long));
  CU_ASSERT_EQUAL(alignmentof(time_t), sizeof(time_t));
  CU_ASSERT_EQUAL(alignmentof(struct MyStruct), alignmentof(struct timespec));
  CU_ASSERT_EQUAL(alignmentof(struct timespec), sizeof(time_t));
}

/* Test fundamental assumptions made by the memory pool */
void llsMP_testSingleThread() {
  llsMP s,/* build one on the stack */
    *h; /* and this is for the heap */
  int* intp1, *intp2;
  char* cp1, *cp2;
  long long *llp1, *llp2;
  struct timespec* tsp1, *tsp2;
  struct MyStruct* msp1, *msp2;

  CU_ASSERT_FATAL(llsMP_alloc(&s, 1, sizeof(char), alignmentof(char)));
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

  CU_ASSERT_FATAL(llsMP_alloc(&s, 2, sizeof(char), alignmentof(char)));
  CU_ASSERT_PTR_NOT_NULL(cp1 = (char*)llsMP_get(&s));
  CU_ASSERT_PTR_NOT_NULL(cp2 = (char*)llsMP_get(&s));
  CU_ASSERT_PTR_EQUAL(cp1 - cp2, alignmentof(char));
  llsMP_free(&s);

  CU_ASSERT_FATAL(llsMP_alloc(&s, 2, sizeof(int), alignmentof(int)));
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

  CU_ASSERT_FATAL(llsMP_alloc(&s, 3, sizeof(long long), alignmentof(long long)));
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

  CU_ASSERT_FATAL(llsMP_alloc(&s, 3, sizeof(struct timespec)
			      , alignmentof(struct timespec)));
  CU_ASSERT_FALSE(llsMP_return(&s, NULL));
  CU_ASSERT_PTR_NOT_NULL(tsp1 = (struct timespec*)llsMP_get(&s));
  CU_ASSERT_PTR_NOT_NULL(tsp2 = (struct timespec*)llsMP_get(&s));
  CU_ASSERT_PTR_EQUAL(tsp1 - tsp2, 1); /* pointer arithmetic */
  CU_ASSERT_PTR_EQUAL((size_t)tsp1 - (size_t)tsp2
		      , sizeof(struct timespec));
  CU_ASSERT_TRUE(llsMP_return(&s, tsp1));
  CU_ASSERT_TRUE(llsMP_return(&s, tsp2));
  llsMP_free(&s);

  CU_ASSERT_FATAL(llsMP_alloc(&s, 3, sizeof(struct MyStruct)
			      , alignmentof(struct MyStruct)));
  CU_ASSERT_FALSE(llsMP_return(&s, NULL));
  CU_ASSERT_PTR_NOT_NULL(msp1 = (struct MyStruct*)llsMP_get(&s));
  CU_ASSERT_PTR_NOT_NULL(msp2 = (struct MyStruct*)llsMP_get(&s));
  CU_ASSERT_PTR_EQUAL(msp1 - msp2, 1); /* pointer arithmetic */
  CU_ASSERT_PTR_EQUAL((size_t)msp1 - (size_t)msp2
		      , sizeof(struct MyStruct));
  CU_ASSERT_TRUE(llsMP_return(&s, msp1));
  CU_ASSERT_TRUE(llsMP_return(&s, msp2));
  llsMP_free(&s);

  h = llsMP_new(2, sizeof(char), alignmentof(char));
  CU_ASSERT_PTR_NOT_NULL_FATAL(h);
  CU_ASSERT_PTR_NOT_NULL(cp1 = (char*)llsMP_get(h));
  CU_ASSERT_PTR_NOT_NULL(cp2 = (char*)llsMP_get(h));
  CU_ASSERT_PTR_EQUAL(cp1 - cp2, sizeof(char));
  CU_ASSERT(llsMP_return(h, cp2));
  CU_ASSERT(llsMP_return(h, cp1));
  llsMP_delete(h);
}

void llsMQ_testSingleThread() {
  llsMQ s,/* build one on the stack */
    *h; /* and this is for the heap */
  int int1, int2;
  char c1 = 'h', c2 = 'c';
  long long ll1 = 0x1234567890abcdef, ll2 = 0x234567890abcdef1;
  struct timespec ts1, ts2;
  struct MyStruct ms1, ms2;

  CU_ASSERT_FATAL(llsMQ_alloc(&s, 0, sizeof(long long), alignmentof(long long)));
  CU_ASSERT_EQUAL(s._memsize, sizeof(long long));
  CU_ASSERT(llsMQ_push(&s, &ll1));
  CU_ASSERT_FALSE(llsMQ_push(&s, &ll2));
  CU_ASSERT(llsMQ_pop(&s, &ll2));
  CU_ASSERT_EQUAL(ll2, ll1);
  CU_ASSERT_FALSE(llsMQ_pop(&s, &ll1));
  ll2 = 0x234567890abcdef1;
  CU_ASSERT(llsMQ_push(&s, &ll2));
  llsMQ_free(&s);

  CU_ASSERT_FATAL(llsMQ_alloc(&s, 1, sizeof(long long), alignmentof(long long)));
  CU_ASSERT_EQUAL(s._memsize, sizeof(long long));
  CU_ASSERT(llsMQ_push(&s, &ll1));
  CU_ASSERT(llsMQ_push(&s, &ll2));
  CU_ASSERT(llsMQ_push(&s, &ll2));
  CU_ASSERT_FALSE(llsMQ_push(&s, &ll1));
  CU_ASSERT(llsMQ_pop(&s, &ll2));
  CU_ASSERT_EQUAL(ll2, ll1);
  CU_ASSERT(llsMQ_pop(&s, &ll2));
  CU_ASSERT_EQUAL(ll2, 0x234567890abcdef1);
  CU_ASSERT(llsMQ_pop(&s, &ll2));
  CU_ASSERT_FALSE(llsMQ_pop(&s, &ll1));
  ll2 = 0x234567890abcdef1;
  CU_ASSERT(llsMQ_push(&s, &ll2));
  llsMQ_free(&s);

  CU_ASSERT_FATAL(llsMQ_alloc(&s, 0, sizeof(char), alignmentof(char)));
  CU_ASSERT_EQUAL(s._memsize, alignmentof(char));
  CU_ASSERT(llsMQ_push(&s, &c1));
  CU_ASSERT_FALSE(llsMQ_push(&s, &c2));
  CU_ASSERT(llsMQ_pop(&s, &c2));
  CU_ASSERT_EQUAL(c2, 'h');
  CU_ASSERT_FALSE(llsMQ_pop(&s, &c1));
  c2 = 'c';
  CU_ASSERT(llsMQ_push(&s, &c2));
  llsMQ_free(&s);
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
  if (!CU_add_test(pSuite, "llsMP_testAlignment", llsMP_testAlignment)
      || !CU_add_test(pSuite, "llsMP_testSingleThread", llsMP_testSingleThread)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  if (!(pSuite = CU_add_suite("llsMQ", init_suite, clean_suite))) {
    CU_cleanup_registry();
    return CU_get_error();
  }
  if (!CU_add_test(pSuite, "llsMQ_testSingleThread", llsMQ_testSingleThread)) {
    CU_cleanup_registry();
    return CU_get_error();
  }

  /* Run all tests using the console interface */
  CU_basic_set_mode(CU_BRM_NORMAL);
  CU_basic_run_tests();
  CU_cleanup_registry();
  return CU_get_error();
}
