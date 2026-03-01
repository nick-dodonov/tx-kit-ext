#include <jni.h>

#include <android/native_activity.h>

#include "droid_argv.h"
#include "droid_log.h"
#include "redirect_stdout.h"

extern int main(int, char**);

/// Pass main() result to DroidActivity for System.exit() in onDestroy.
static void set_exit_code(ANativeActivity* activity, int code)
{
    JNIEnv* env = nullptr;
    if (activity->vm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
        LOGW("AttachCurrentThread failed");
        return;
    }
    jclass clazz = env->GetObjectClass(activity->clazz);
    if (!clazz) return;
    jmethodID setExitCode = env->GetMethodID(clazz, "setExitCode", "(I)V");
    if (!setExitCode) {
        LOGW("GetMethodID setExitCode failed");
        return;
    }
    env->CallVoidMethod(activity->clazz, setExitCode, (jint)code);
}

JNIEXPORT void ANativeActivity_onCreate(ANativeActivity* activity, void* savedState, size_t savedStateSize)
{
    LOGW("starting main(): activity=%p savedState=%p savedStateSize=%zu", activity, savedState, savedStateSize);

    redirect_stdout_to_logcat();

    DroidArgv argv(activity);
    int result = main(argv.argc(), argv.argv());

    LOGW("finished main(): %d", result);
    set_exit_code(activity, result);
    ANativeActivity_finish(activity);
}
