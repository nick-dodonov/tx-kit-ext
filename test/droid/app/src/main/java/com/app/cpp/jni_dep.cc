#include "jni_dep.h"

int calculate(int a, int b) {
  __android_log_write(3, "MyTag", "foobar");
  return a + b * 20 + 1000;
}
