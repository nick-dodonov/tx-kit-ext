#include <jni.h>
#include <android/native_activity.h>
#include <unistd.h>

#include "droid_log.h"
#include "redirect_stdout.h"

extern int main(int, char**);

static void crash()
{
    LOGW("crash()");
    int* p = nullptr;
    *p = 1;
    (void)p;
}

JNIEXPORT void ANativeActivity_onCreate(ANativeActivity* activity, void* savedState, size_t savedStateSize)
{
    LOGW("starting main(): activity=%p savedState=%p savedStateSize=%zu", activity, savedState, savedStateSize);
    //_exit(111);
    //crash();

    redirect_stdout_to_logcat();
    int result = main(0, nullptr);

    LOGW("finished main(): %d", result);
    ANativeActivity_finish(activity);
}
