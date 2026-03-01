#include <gtest/gtest.h>
#include <iostream>

#include "cc_lib.h"

TEST(CcTest, Works) {
    std::cout << "Test message" << std::endl;
    EXPECT_TRUE(true);
}

TEST(CcTest, Greeting) {
    EXPECT_EQ(get_greeting("World"), "Hello, World!");
}

TEST(CcTest, DISABLED_Failure) { // Only when explicitly requested to run, e.g. by name filter
    GTEST_FAIL() << "Must fail";
}
