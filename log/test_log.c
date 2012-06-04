#include <string.h> /* for memcpy */
#include "log.h"
#include "gtest/gtest.h"

TEST(LogTest, Fatal) {
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
