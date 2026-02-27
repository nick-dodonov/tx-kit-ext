// Bridge: android_main() -> main(0, nullptr) for reusing code with main() entry point.
#include "redirect_stdout.h"
#include "droid_log.h"
#include "sources/android/native_app_glue/android_native_app_glue.h"
#include <iostream>

extern int main(int, char**);

void android_main(struct android_app* state)
{
    LOGD("android_main() start: %s", state->activity->internalDataPath);
    app_dummy();  // Keep ANativeActivity_onCreate from being stripped (ref: android/ndk#381)

    redirect_stdout_to_logcat();
    // printf("Hello from printf\n");
    // std::cout << "Hello from std::cout" << std::endl;

    int result = main(0, nullptr);
    LOGD("android_main() exit: %d", result);
}
