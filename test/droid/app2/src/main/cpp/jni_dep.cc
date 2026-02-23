#include "jni_dep.h"
#include "sources/android/native_app_glue/android_native_app_glue.h"

#include <android/log.h>
#include <stdlib.h>

#define LOG_TAG "NatApp"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define ASSERT(cond, fmt, ...)                                \
  if (!(cond)) {                                              \
    __android_log_assert(#cond, LOG_TAG, fmt, ##__VA_ARGS__); \
  }

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

extern "C" void android_main(struct android_app* state)
{
  LOGI("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-ANDROID-MAIN-2");
  //exit(1);
}
