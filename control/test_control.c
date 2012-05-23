// system calls ///////////////////////////////////////////
#include <stdio.h>
#include <getopt.h>
#include <unistd.h>
#include <math.h>

// 3rd party stuff ////////////////////////////////////////
#include "gtest/gtest.h"

// my code ////////////////////////////////////////////////
#include "log.h"
#include "estimator.h"
#include "model.h"

class ThermalTest : public ::testing::Test {
 protected:
  // You can remove any or all of the following functions if its body
  // is empty.

  ThermalTest() { 
  }
  virtual ~ThermalTest() {
  }
  // If the constructor and destructor are not enough for setting up
  // and cleaning up each test, you can define the following methods:
  virtual void SetUp() { 
    period = 1.f, ambient = 19.f, R = 10.f, C = 1.0f;
    outf = fopen("ThermalTest.csv", "w");
  }
  virtual void TearDown() {
    if(outf) fclose(outf);
  }
  // Objects declared here can be used by all tests in the test case}
  FILE* outf;
  float period, ambient, R, C, disturbance;
};

TEST_F(ThermalTest, nodisturbance) {
  Thermal well(period, ambient, R, C, disturbance=0);
  for(int i = 0; i < 100; ++i) {
    well.update(0, ambient);
    EXPECT_EQ(well.T, ambient);
  }
}

TEST_F(ThermalTest, disturbance) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  float avg = 0;
  const int N = 200;
  for(int i = 0; i < N; ++i) {
    well.update(0, ambient);
    avg += well.T;
    fprintf(outf, "%f\n", well.T);
  } avg /= N;
  EXPECT_LT(fabs(avg - ambient), 1E-2);
}

TEST_F(ThermalTest, impulse_ambient) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  ambient -= 10.f;
  for(int i = 0; i < 200; ++i) {
    well.update(0, ambient);
    fprintf(outf, "%f\n", well.T);
  }
  EXPECT_LT(fabs(well.T - ambient), 0.1f);
}

TEST_F(ThermalTest, impulse_heat) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  float qin = 0.5f;
  for(int i = 0; i < 200; ++i) {
    well.update(qin, ambient);
    fprintf(outf, "%f\n", well.T);
  }
  float Te = ambient + R * C * qin;
  EXPECT_LT(fabs(well.T - Te), 0.1f);
}

TEST_F(ThermalTest, dirac_heat) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  float qin = 0.5f;
  well.update(qin, ambient);
  for(int i = 0; i < 200; ++i) {
    well.update(0, ambient);
    fprintf(outf, "%f\n", well.T);
  }
  EXPECT_LT(fabs(well.T - ambient), 0.1f);
}

TEST(LowpassTest, impulse) {
  float z[30];
  size_t i, window = 20, order = 1;
  Lowpass f(window, 1);
  float cutoffhz = 1.0f, sampling_period = 0.1f;
  ASSERT_TRUE(f.reset(cutoffhz, sampling_period));

  for(i = 0; i < 19; ++i) {
    EXPECT_TRUE(f.update(0));
  }
  EXPECT_EQ(f.mean, 0);
  EXPECT_EQ(f.sigma, 0);
  EXPECT_EQ(f.period, sampling_period);
  EXPECT_EQ(f.cutoffhz, cutoffhz);
  EXPECT_EQ(f.xe, 0);
  EXPECT_EQ(f.xdote, 0);

  for(i = 0; i < 20; ++i) {
    EXPECT_TRUE(f.update(-1.0f * window));
    EXPECT_EQ(f.mean, -1.0f * (float)(i + 1));
    EXPECT_LT(f.xdote, 0);
  }

  float error = f.xe - (-1.0f * window);
  EXPECT_LT(fabs(error), 1E-4);
  EXPECT_GT(f.xdote, -1E-3);
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
