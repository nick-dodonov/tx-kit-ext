#include <jni.h>

#include <android/native_activity.h>

#include "droid_argv.h"
#include "droid_log.h"
#include "redirect_stdout.h"

extern int main(int, char**);

static JNIEnv* _env = nullptr;

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
    LOGD("starting main()");

    DroidArgv argv(activity, _env);
    int result = main(argv.argc(), argv.argv());

    LOGD("finished main(): %d", result);

    finishProcess(activity, _env, result);
    //LOGV("finishing activity");
    //ANativeActivity_finish(activity);
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

//JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved);
JNIEXPORT void ANativeActivity_onCreate(ANativeActivity* activity, void* savedState, size_t savedStateSize)
{
    LOGD("onCreate: %p savedState=%p savedStateSize=%zu", activity, savedState, savedStateSize);
    //JNI_OnLoad(activity->vm, nullptr);

    if (activity->vm->AttachCurrentThread(&_env, nullptr) != JNI_OK) {
        LOGE("AttachCurrentThread failed");
        ANativeActivity_finish(activity);
        return;
    }

    activity->callbacks->onStart = onStart;
    activity->callbacks->onStop = onStop;

    redirect_stdout_to_logcat();
}
