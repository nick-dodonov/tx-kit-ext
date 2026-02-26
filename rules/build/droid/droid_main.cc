// Bridge: android_main() -> main(0, nullptr) for reusing code with main() entry point.
#include "sources/android/native_app_glue/android_native_app_glue.h"
#include <android/log.h>

#define LOG_TAG "droid_main"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern int main(int, char**);

void android_main(struct android_app* state) {
    LOGI("================================ >>");
    int result = main(0, nullptr);
    LOGI("================================ << %d", result);
}
