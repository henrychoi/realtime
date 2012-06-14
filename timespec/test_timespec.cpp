#include <string.h> /* for memcpy */
#include "timespec.h"
#include "gtest/gtest.h"

TEST(TimespecTest, Type) {
  struct timespec t1 = {0x12345678, 12345678}, t2;
  long long u64t1, u64t2;

  EXPECT_EQ(sizeof(u64t1), 8);
  EXPECT_EQ(sizeof(t1), 8);

  memcpy(&u64t1, &t1, sizeof(u64t1));
  EXPECT_EQ(memcmp(&u64t1, &t1, sizeof(u64t1)), 0);

  u64t2 = u64t1;
  EXPECT_EQ(u64t1, u64t2);

  memcpy(&t2, &u64t2, sizeof(u64t2));
  EXPECT_EQ(memcmp(&t2, &u64t2, sizeof(u64t2)), 0);

  EXPECT_TRUE(timespec_equal(t1, t2));
}

void test_arithmetic() {
  struct timespec time, t1, t2;
  time = TIMESPEC_ZERO; t1 = TIMESPEC_ZERO;
  timespec_sub(time, t1);
  EXPECT_FALSE(timespec_nz(time));

  time = TIMESPEC_ZERO; t1 = TIMESPEC_NANOSEC;
  timespec_sub(time, t1);
  timespec_add_ns(time, 1);
  EXPECT_FALSE(timespec_nz(time));

  time = TIMESPEC_ZERO; t1 = TIMESPEC_NANOSEC, t2 = TIMESPEC_MICROSEC;
  timespec_add_ns(time, 1001);
  timespec_sub(time, t1);
  EXPECT_TRUE(timespec_equal(time, t2));
}
void test_toString() {
   char s[TIMESPEC_STRING_LEN];
   struct timespec time;

   EXPECT_STREQ(timespec_toString(&TIMESPEC_ZERO,s,1.f, 0), "0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_ZERO,s,1.f, 1), "0.0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_ZERO,s,1000.f, 1), "0.0");

   EXPECT_STREQ(timespec_toString(&TIMESPEC_SEC,s,1.f, 0), "1");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_SEC,s,1.f, 1), "1.0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_SEC,s,1000.f,1), "1000.0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_SEC,s,.001f, 1), "0.0");

   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 0), "0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 1), "0.0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 2), "0.00");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1.f, 3), "0.001");

   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1E1f, 1), "0.0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1E2f, 1), "0.1");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1E3f, 1), "1.0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1E3f, 0), "1");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_MILLISEC,s, 1E3f, 2), "1.00");

   EXPECT_STREQ(timespec_toString(&TIMESPEC_NANOSEC,s, 1E0f, 0), "0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_NANOSEC,s, 1E0f, 1), "0.0");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_NANOSEC,s, 1E8f, 1), "0.1");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_NANOSEC,s, 1E9f, 0), "1");
   EXPECT_STREQ(timespec_toString(&TIMESPEC_NANOSEC,s, 1E9f, 1), "1.0");

   time = TIMESPEC_ZERO; timespec_sub(time, TIMESPEC_NANOSEC);
   EXPECT_STREQ(timespec_toString(&time, s, 1E9f, 0), "-1");
   EXPECT_STREQ(timespec_toString(&time, s, 1E9f, 1), "-1.0");

   time = TIMESPEC_ZERO; timespec_sub(time, TIMESPEC_MICROSEC);
   EXPECT_STREQ(timespec_toString(&time, s, 1E6f, 0), "-1");
   EXPECT_STREQ(timespec_toString(&time, s, 1E6f, 1), "-1.0");
   EXPECT_STREQ(timespec_toString(&time, s, 1E9f, 1), "-1000.0");
   EXPECT_STREQ(timespec_toString(&time, s, 1E3f, 3), "-0.001");

   EXPECT_EQ(printf("%s", timespec_toString(&time, s, 1E3f, 3)),
		   strlen("-0.001"));
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
