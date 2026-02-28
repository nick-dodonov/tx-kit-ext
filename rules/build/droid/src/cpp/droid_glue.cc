#include <jni.h>
#include <android/native_activity.h>

#include "droid_log.h"
#include "redirect_stdout.h"

extern int main(int, char**);

JNIEXPORT void ANativeActivity_onCreate(ANativeActivity* activity, void* savedState, size_t savedStateSize)
{
    LOGD("onCreate: activity=%p savedState=%p savedStateSize=%zu", activity, savedState, savedStateSize);
    redirect_stdout_to_logcat();

    int result = main(0, nullptr);
    LOGD("onCreate: result=%d", result);

    ANativeActivity_finish(activity);
}
