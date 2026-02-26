// Bridge: android_main() -> main(0, nullptr) for reusing code with main() entry point.
#include "redirect_stdout.h"
#include "sources/android/native_app_glue/android_native_app_glue.h"

extern int main(int, char**);

void android_main(struct android_app* state) {
    app_dummy();  // Keep ANativeActivity_onCreate from being stripped (ref: android/ndk#381)
    redirect_stdout_to_logcat();

    int result = main(0, nullptr);
    (void)result;
}
