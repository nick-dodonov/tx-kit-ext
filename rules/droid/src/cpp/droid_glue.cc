#include <jni.h>

#include <android/native_activity.h>

#include "droid_activity.h"
#include "droid_argv.h"
#include "droid_log.h"
#include "redirect_stdout.h"

//#define ALLOW_WEAK_MAIN

#ifdef ALLOW_WEAK_MAIN
// Declare as weak - linker won't fail if not defined.
// This allows completely override glue (for example by SdlActivity and its own mechanism to call main()).
__attribute__((weak))
#endif
int main(int argc, char* argv[]);

// Global ANativeActivity pointer for access from application code
ANativeActivity* g_NativeActivity = nullptr;

namespace 
{
    JNIEnv* _env = nullptr;
}

/// Pass main() result to DroidActivity for System.exit() in onDestroy.
static void finishProcess(ANativeActivity* activity, JNIEnv* env, int code)
{
    LOGV("finishProcess: %d", code);
    jclass clazz = env->GetObjectClass(activity->clazz);
    if (!clazz) {
        LOGE("finishProcess: GetObjectClass failed");
        return;
    }
    jmethodID method = env->GetMethodID(clazz, "finishProcess", "(I)V");
    if (!method) {
        LOGE("finishProcess: GetMethodID failed");
        return;
    }
    env->CallVoidMethod(activity->clazz, method, (jint)code);
}

static void callMain(ANativeActivity* activity)
{
#ifdef ALLOW_WEAK_MAIN
    // Require application provides "standard" main() entry point
    if (main == nullptr) {
        LOGE("main() must be implemented!");
        finishProcess(activity, _env, 127); // 127 is commonly used to indicate "command not found"
        return;
    }
#endif

    LOGD("---> main()");

    DroidArgv argv(activity, _env);
    int result = main(argv.argc(), argv.argv());

    LOGD("<--- main(): %d", result);

    finishProcess(activity, _env, result);
}

static void onStart(ANativeActivity* activity)
{
    LOGD("onStart: %p", activity);
    callMain(activity);
}

static void onStop(ANativeActivity* activity)
{
    LOGD("onStop: %p", activity);
}

JNIEXPORT void ANativeActivity_onCreate(ANativeActivity* activity, void* savedState, size_t savedStateSize)
{
    LOGD("onCreate: %p savedState=%p savedStateSize=%zu", activity, savedState, savedStateSize);

    g_NativeActivity = activity;  // Store globally for application access

    if (activity->vm->AttachCurrentThread(&_env, nullptr) != JNI_OK) {
        LOGE("AttachCurrentThread failed");
        ANativeActivity_finish(activity);
        return;
    }

    activity->callbacks->onStart = onStart;
    activity->callbacks->onStop = onStop;

    redirect_stdout_to_logcat();
}
