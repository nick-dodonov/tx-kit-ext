// Bridge: android_main() -> main(0, nullptr) for reusing code with main() entry point.
#include "sources/android/native_app_glue/android_native_app_glue.h"

extern int main(int, char**);

void android_main(struct android_app* state) {
    main(0, nullptr);
}
