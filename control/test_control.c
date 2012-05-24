// system calls ///////////////////////////////////////////
#include <stdio.h>
#include <getopt.h>
#include <unistd.h>
#include <math.h>

// 3rd party stuff ////////////////////////////////////////
#include "gtest/gtest.h"

// my code ////////////////////////////////////////////////
#include "log/log.h"
#include "control/model.h"
#include "control/sensor.h"
#include "control/estimator.h"
#include "control/trajectory.h"

class ControlTest : public ::testing::Test {
 protected:
  virtual void SetUp() { 
    outf = fopen(__FILE__".log", "w");
  }
  virtual void TearDown() {
    if(outf) fclose(outf);
  }
  FILE* outf;
};

class ThermalTest : public ControlTest {
 protected:
  virtual void SetUp() { 
    ControlTest::SetUp();
    period = 1.f, ambient = 19.f, R = 10.f, C = 1.0f;
  }
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
    if(outf) fprintf(outf, "%f\n", well.T);
  } avg /= N;
  EXPECT_LT(fabs(avg - ambient), 1E-2);
}

TEST_F(ThermalTest, impulse_ambient) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  ambient -= 10.f;
  for(int i = 0; i < 200; ++i) {
    well.update(0, ambient);
    if(outf) fprintf(outf, "%f\n", well.T);
  }
  EXPECT_LT(fabs(well.T - ambient), 0.1f);
}

TEST_F(ThermalTest, impulse_heat) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  float qin;
  for(int i = 0; i < 200; ++i) {
    well.update(qin = 0.5f, ambient);
    if(outf) fprintf(outf, "%f\n", well.T);
  }
  float Te = ambient + R * C * qin;
  EXPECT_LT(fabs(well.T - Te), 0.1f);
}

TEST_F(ThermalTest, delta_heat) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  float qin;
  well.update(qin = 0.5f, ambient);
  for(int i = 0; i < 200; ++i) {
    well.update(qin = 0, ambient);
    if(outf) fprintf(outf, "%f\n", well.T);
  }
  EXPECT_LT(fabs(well.T - ambient), 0.1f);
}

TEST_F(ThermalTest, read) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  float noise, bad_fraction;
  BadThermalSensor sensor(well, noise = 0.25f, bad_fraction = 0.01f);
  float qin;

  for(int i = 0; i < 200; ++i) {
    well.update(qin = 0, ambient);
    if(outf) fprintf(outf, "%f\n", sensor.read());
  }
}

TEST_F(ThermalTest, estimate) {
  Thermal well(period, ambient, R, C, disturbance=0.05f);
  float noise, bad_fraction;
  BadThermalSensor sensor(well, noise = 0.25f, bad_fraction = 0.7f);
  ScalarLowpass estimator;
  float cutoffhz = 1.f/(R*C), sampling_period = 0.1f / cutoffhz;
  ASSERT_TRUE(estimator.reset(ambient, cutoffhz, sampling_period));

  const float qin = 0;
  int n_outlier = 0;
  for(int i = 0; i < 2000; ++i) {
    well.update(0, ambient);
    float raw = sensor.read();
    if(!estimator.update(raw)) {
      n_outlier++;
      estimator.reset(estimator.xe //reset with last good estimate
		      , cutoffhz, sampling_period);
    }
    if(outf) fprintf(outf, "%f, %f\n", raw, estimator.xe);
  }
  EXPECT_GT(n_outlier, 0);
}

TEST(LowpassTest, impulse) {
  float z[30];
  size_t i, window = 20, order = 1;
  ScalarLowpass f(window, 1);
  float cutoffhz = 1.0f, sampling_period = 0.1f, initial;
  ASSERT_TRUE(f.reset(initial = 0, cutoffhz, sampling_period));

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

class BangBangTest : public ControlTest {
 protected:
  ScalarBangBangTrajectory traj;
  float period, x0, xf, max_vel, max_acc, max_dec;
  virtual void SetUp() { 
    ControlTest::SetUp();
    period = 0.05f, max_vel = 1.1f, max_acc = 1.f, max_dec = 2.f;
  }
};

TEST_F(BangBangTest, positive) {
  x0 = -2.f, xf = 2.f;
  EXPECT_TRUE(traj.reset(period, x0, xf, max_vel, max_acc, max_dec));
  EXPECT_EQ(traj.p, x0);
  EXPECT_EQ(traj.v, 0);
  EXPECT_EQ(traj.a, max_acc);
  if(outf) fprintf(outf, "%f, %f, %f\n", traj.a, traj.v, traj.p);
  traj.update();
  while(traj.k * period <= traj.tf[2]) {
    traj.update();
    if(outf) fprintf(outf, "%f, %f, %f\n", traj.a, traj.v, traj.p);
  }
  traj.update();
  if(outf) fprintf(outf, "%f, %f, %f\n", traj.a, traj.v, traj.p);
  EXPECT_LT(fabs(traj.p - xf), 1E-6);
  EXPECT_EQ(traj.v, 0);
  EXPECT_EQ(traj.a, 0);
}


int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
