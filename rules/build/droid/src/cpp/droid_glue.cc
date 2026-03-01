#include <jni.h>

#include <android/native_activity.h>

#include "droid_argv.h"
#include "droid_log.h"
#include "redirect_stdout.h"

extern int main(int, char**);

/// Pass main() result to DroidActivity for System.exit() in onDestroy.
static void set_exit_code(ANativeActivity* activity, JNIEnv* env, int code)
{
    jclass clazz = env->GetObjectClass(activity->clazz);
    if (!clazz) return;
    jmethodID setExitCode = env->GetMethodID(clazz, "setExitCode", "(I)V");
    if (!setExitCode) return;
    env->CallVoidMethod(activity->clazz, setExitCode, (jint)code);
}

JNIEXPORT void ANativeActivity_onCreate(ANativeActivity* activity, void* savedState, size_t savedStateSize)
{
    LOGD("starting main(): activity=%p savedState=%p savedStateSize=%zu", activity, savedState, savedStateSize);

    JNIEnv* env = nullptr;
    if (activity->vm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
        LOGE("AttachCurrentThread failed");
        ANativeActivity_finish(activity);
        return;
    }

    redirect_stdout_to_logcat();

    DroidArgv argv(activity, env);
    int result = main(argv.argc(), argv.argv());

    LOGD("finished main(): %d", result);
    set_exit_code(activity, env, result);
    ANativeActivity_finish(activity);
}
