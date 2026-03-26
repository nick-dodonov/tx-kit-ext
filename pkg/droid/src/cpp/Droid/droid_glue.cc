#include <jni.h>

#include <android/native_activity.h>

#include "Glue.h"
#include "droid_argv.h"
#include "droid_log.h"
#include "redirect_stdout.h"

int main(int argc, char* argv[]);

namespace {
    /// Glue implementation over ANativeActivity
    class NativeGlue : public Droid::Glue
    {
        ANativeActivity* _activity{};
        JNIEnv* _env{};
        AAssetManager* _assetManager{};

    public:
        void Init(ANativeActivity* activity) 
        {
            SetInternal(this);

            _activity = activity;

            if (activity->vm->AttachCurrentThread(&_env, nullptr) != JNI_OK) {
                LOGE("AttachCurrentThread failed");
                ANativeActivity_finish(activity);
                return;
            }

            _assetManager = activity->assetManager;
        }

        // Droid::Glue
        [[nodiscard]] JNIEnv* GetMainJNIEnv() const override { return _env; }
        [[nodiscard]] AAssetManager* GetAssetManager() const override { return _assetManager; }
    };

    NativeGlue nativeGlue;
}

/// Pass main() result to DroidActivity for System.exit() in onDestroy.
static void finishProcess(ANativeActivity* activity, JNIEnv* env, int code)
{
    LOGV("finishProcess: %d", code);
    auto clazz = env->GetObjectClass(activity->clazz);
    if (!clazz) {
        LOGE("finishProcess: GetObjectClass failed");
        return;
    }
    auto method = env->GetMethodID(clazz, "finishProcess", "(I)V");
    if (!method) {
        LOGE("finishProcess: GetMethodID failed");
        return;
    }
    env->CallVoidMethod(activity->clazz, method, (jint)code);
}

static void callMain(ANativeActivity* activity)
{
    LOGD("---> main()");

    auto* env = nativeGlue.GetMainJNIEnv();
    DroidArgv argv(activity, env);
    int result = main(argv.argc(), argv.argv());

    LOGD("<--- main(): %d", result);

    finishProcess(activity, env, result);
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
    nativeGlue.Init(activity);

    activity->callbacks->onStart = onStart;
    activity->callbacks->onStop = onStop;

    redirect_stdout_to_logcat();
}
