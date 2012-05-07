#include <time.h> /* for struct timespec */
#include "gtest/gtest.h"
#include "llsQ.h"
#include "llsMP.h"
#include "llsMQ.h"

struct MyStruct {
  char ca, cb;
  struct timespec early, late;
  short sa, sb;
  int ia;
  long la;
  long long lla;
};

TEST(llsMP_Test, Alignment) {
  EXPECT_EQ(__alignof__(char), sizeof(char));
  EXPECT_EQ(__alignof__(void*), sizeof(void*));
  EXPECT_EQ(__alignof__(short), sizeof(short));  
  EXPECT_EQ(__alignof__(int), sizeof(int));
  EXPECT_GT(__alignof__(long long), __alignof__(long));
  EXPECT_EQ(__alignof__(time_t), sizeof(time_t));
  EXPECT_EQ(__alignof__(struct MyStruct), __alignof__(struct timespec));
  EXPECT_EQ(__alignof__(struct timespec), sizeof(time_t));
}

TEST(llsMP_Test, Character) {
  llsMP s;/* build one on the stack */
  char* cp1, *cp2;
  ASSERT_TRUE(llsMP_alloc(&s, 1, sizeof(char), __alignof__(char)));
  EXPECT_EQ(s._available, 1);
  EXPECT_TRUE(cp1 = (char*)llsMP_get(&s));
  EXPECT_EQ(s._available, 0);
  *cp1 = 'h';
  EXPECT_FALSE(llsMP_get(&s));
  EXPECT_TRUE(llsMP_return(&s, cp1));
  EXPECT_FALSE(llsMP_return(&s, cp1));
  EXPECT_TRUE(cp2 = (char*)llsMP_get(&s));
  EXPECT_EQ(cp1, cp2);
  EXPECT_EQ(*cp2, 'h');
  llsMP_free(&s);

  ASSERT_TRUE(llsMP_alloc(&s, 2, sizeof(char), __alignof__(char)));
  EXPECT_TRUE(cp1 = (char*)llsMP_get(&s));
  EXPECT_TRUE(cp2 = (char*)llsMP_get(&s));
  EXPECT_EQ(cp1 - cp2, __alignof__(char));
  llsMP_free(&s);

  llsMP* h = llsMP_new(2, sizeof(char), __alignof__(char));
  ASSERT_TRUE(h);
  EXPECT_TRUE(cp1 = (char*)llsMP_get(h));
  EXPECT_TRUE(cp2 = (char*)llsMP_get(h));
  EXPECT_EQ(cp1 - cp2, sizeof(char));
  EXPECT_TRUE(llsMP_return(h, cp2));
  EXPECT_TRUE(llsMP_return(h, cp1));
  llsMP_delete(h);
}


TEST(llsMP_Test, Integer) {
  llsMP s;/* build one on the stack */
  int* intp1, *intp2;

  ASSERT_TRUE(llsMP_alloc(&s, 2, sizeof(int), __alignof__(int)));
  EXPECT_FALSE(llsMP_return(&s, NULL));
  EXPECT_TRUE(intp1 = (int*)llsMP_get(&s));
  EXPECT_TRUE(intp2 = (int*)llsMP_get(&s));
  EXPECT_EQ(intp1 - intp2, 1); /* pointer arithmetic */
  EXPECT_EQ((size_t)intp1 - (size_t)intp2, sizeof(int));
  EXPECT_EQ(*intp1 = 1234, 1234);
  EXPECT_FALSE(llsMP_get(&s));
  EXPECT_TRUE(llsMP_return(&s, intp1));
  EXPECT_TRUE(llsMP_return(&s, intp2));
  EXPECT_FALSE(llsMP_return(&s, intp1));
  llsMP_free(&s);
}
TEST(llsMP_Test, LongInt) {
  llsMP s;/* build one on the stack */
  long long *llp1, *llp2;
  ASSERT_TRUE(llsMP_alloc(&s, 3, sizeof(long long), __alignof__(long long)));
  EXPECT_FALSE(llsMP_return(&s, NULL));
  EXPECT_TRUE(llp1 = (long long*)llsMP_get(&s));
  EXPECT_TRUE(llp2 = (long long*)llsMP_get(&s));
  EXPECT_EQ(llp1 - llp2, 1); /* pointer arithmetic */
  EXPECT_EQ((size_t)llp1 - (size_t)llp2, sizeof(long long));
  EXPECT_EQ(*llp1 = 1234, 1234);
  EXPECT_TRUE(llsMP_return(&s, llp1));
  EXPECT_TRUE(llsMP_return(&s, llp2));
  EXPECT_EQ(s._available, 3);
  llsMP_free(&s);
 }

TEST(llsMP_Test, Timespec) {
  llsMP s;/* build one on the stack */
  struct timespec* tsp1, *tsp2;
  ASSERT_TRUE(llsMP_alloc(&s, 3, sizeof(struct timespec)
			      , __alignof__(struct timespec)));
  EXPECT_FALSE(llsMP_return(&s, NULL));
  EXPECT_TRUE(tsp1 = (struct timespec*)llsMP_get(&s));
  EXPECT_TRUE(tsp2 = (struct timespec*)llsMP_get(&s));
  EXPECT_EQ(tsp1 - tsp2, 1); /* pointer arithmetic */
  EXPECT_EQ((size_t)tsp1 - (size_t)tsp2
		      , sizeof(struct timespec));
  EXPECT_TRUE(llsMP_return(&s, tsp1));
  EXPECT_TRUE(llsMP_return(&s, tsp2));
  llsMP_free(&s);
 }

TEST(llsMP_Test, MyStruct) {
  llsMP s;/* build one on the stack */
  struct MyStruct* msp1, *msp2;
  ASSERT_TRUE(llsMP_alloc(&s, 3, sizeof(struct MyStruct)
			  , __alignof__(struct MyStruct)));
  EXPECT_FALSE(llsMP_return(&s, NULL));
  EXPECT_TRUE(msp1 = (struct MyStruct*)llsMP_get(&s));
  EXPECT_TRUE(msp2 = (struct MyStruct*)llsMP_get(&s));
  EXPECT_EQ(msp1 - msp2, 1); /* pointer arithmetic */
  EXPECT_EQ((size_t)msp1 - (size_t)msp2
		      , sizeof(struct MyStruct));
  EXPECT_TRUE(llsMP_return(&s, msp1));
  EXPECT_TRUE(llsMP_return(&s, msp2));
  llsMP_free(&s);
}

TEST(llsMQ_Test, LongInteger) {
  llsMQ s;/* build one on the stack */
  long long ll1 = 0x1234567890abcdef, ll2 = 0x234567890abcdef1;

  ASSERT_TRUE(llsMQ_alloc(&s, 0, sizeof(long long)));
  EXPECT_EQ(s._memsize, sizeof(long long));
  EXPECT_TRUE(llsMQ_push(&s, &ll1));
  EXPECT_FALSE(llsMQ_push(&s, &ll2));
  EXPECT_TRUE(llsMQ_pop(&s, &ll2));
  EXPECT_EQ(ll2, ll1);
  EXPECT_FALSE(llsMQ_pop(&s, &ll1));
  ll2 = 0x234567890abcdef1;
  EXPECT_TRUE(llsMQ_push(&s, &ll2));
  llsMQ_free(&s);

  ASSERT_TRUE(llsMQ_alloc(&s, 1, sizeof(long long)));
  EXPECT_EQ(s._memsize, sizeof(long long));
  EXPECT_TRUE(llsMQ_push(&s, &ll1));
  EXPECT_TRUE(llsMQ_push(&s, &ll2));
  EXPECT_TRUE(llsMQ_push(&s, &ll2));
  EXPECT_FALSE(llsMQ_push(&s, &ll1));
  EXPECT_TRUE(llsMQ_pop(&s, &ll2));
  EXPECT_EQ(ll2, ll1);
  EXPECT_TRUE(llsMQ_pop(&s, &ll2));
  EXPECT_EQ(ll2, 0x234567890abcdef1);
  EXPECT_TRUE(llsMQ_pop(&s, &ll2));
  EXPECT_FALSE(llsMQ_pop(&s, &ll1));
  ll2 = 0x234567890abcdef1;
  EXPECT_TRUE(llsMQ_push(&s, &ll2));
  llsMQ_free(&s);
}
TEST(llsMQ_Test, Character) {
  llsMQ s;/* build one on the stack */
  char c1 = 'h', c2 = 'c';
  ASSERT_TRUE(llsMQ_alloc(&s, 0, sizeof(char)));
  EXPECT_EQ(s._memsize, sizeof(char));
  EXPECT_TRUE(llsMQ_push(&s, &c1));
  EXPECT_FALSE(llsMQ_push(&s, &c2));
  EXPECT_TRUE(llsMQ_pop(&s, &c2));
  EXPECT_EQ(c2, 'h');
  EXPECT_FALSE(llsMQ_pop(&s, &c1));
  c2 = 'c';
  EXPECT_TRUE(llsMQ_push(&s, &c2));
  llsMQ_free(&s);
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
