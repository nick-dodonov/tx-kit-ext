#include "jni_dep.h"

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

int calculate(int a, int b) {
  __android_log_write(3, "MyTag", "================================");
  __android_log_write(3, "MyTag", "COMPILED: " __DATE__ " " __TIME__);
#if defined(__clang__)
  __android_log_write(3, "MyTag", "CLANG: " TOSTRING(__clang_major__) "." TOSTRING(__clang_minor__) "." TOSTRING(__clang_patchlevel__));
#endif
#if defined(__cplusplus)
  __android_log_write(3, "MyTag", "__cplusplus: " TOSTRING(__cplusplus));
#endif
  __android_log_write(3, "MyTag", "================================");
  return a + b * 20 + 1000;
}
