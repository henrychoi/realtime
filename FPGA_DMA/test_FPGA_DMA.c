// system calls ///////////////////////////////////////////
#include <stdio.h>
#include <getopt.h>
#include <unistd.h>
#include <math.h>

// 3rd party stuff ////////////////////////////////////////
#include "gtest/gtest.h"

// my code ////////////////////////////////////////////////
#include "log/log.h"

TEST(ThroughputTest, Read) {
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
