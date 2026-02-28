// Bridge: (native_app_glue) android_main() -> main(0, nullptr) for standard entry point.

// DISABLED: in favor of self-implemented droid_glue.cc (TODO: remove when everything useful in native_app_glue will be known)
//  to workaround native_app_glue issues w/ finish
//  it never gives APP_CMD_DESTROY after direct ANativeActivity_finish 
//      (tried after all variants of current state)
#if false
#include "redirect_stdout.h"
#include "droid_log.h"
#include "sources/android/native_app_glue/android_native_app_glue.h"

#include <iostream>
#include <cstdlib> // Required for std::abort

extern int main(int, char**);

void HandleCmd(struct android_app* state, int32_t cmd)
{
    switch (cmd) {
    case APP_CMD_INPUT_CHANGED: LOGV("APP_CMD_INPUT_CHANGED"); break;

    case APP_CMD_INIT_WINDOW: LOGV("APP_CMD_INIT_WINDOW"); break;
    case APP_CMD_TERM_WINDOW: LOGV("APP_CMD_TERM_WINDOW"); break;

    case APP_CMD_WINDOW_RESIZED: LOGV("APP_CMD_WINDOW_RESIZED"); break;
    case APP_CMD_WINDOW_REDRAW_NEEDED: LOGV("APP_CMD_WINDOW_REDRAW_NEEDED"); break;
    case APP_CMD_CONTENT_RECT_CHANGED: LOGV("APP_CMD_CONTENT_RECT_CHANGED"); break;

    case APP_CMD_GAINED_FOCUS: LOGV("APP_CMD_GAINED_FOCUS"); break;
    case APP_CMD_LOST_FOCUS: LOGV("APP_CMD_LOST_FOCUS"); break;


    case APP_CMD_CONFIG_CHANGED: LOGV("APP_CMD_CONFIG_CHANGED"); break;
    case APP_CMD_LOW_MEMORY: LOGV("APP_CMD_LOW_MEMORY"); break;

    case APP_CMD_START: LOGV("APP_CMD_START"); break;
    case APP_CMD_RESUME: LOGV("APP_CMD_RESUME"); break;

    case APP_CMD_SAVE_STATE: LOGV("APP_CMD_SAVE_STATE"); break;

    case APP_CMD_PAUSE: LOGV("APP_CMD_PAUSE"); break;
    case APP_CMD_STOP: LOGV("APP_CMD_STOP"); break;

    case APP_CMD_DESTROY: LOGV("APP_CMD_DESTROY"); break;

    default:
        LOGW("APP_CMD_*: %d (unknown)", cmd);
        break;
    }
}

void android_main(struct android_app* state)
{
    LOGD("android_main() start: %s", state->activity->internalDataPath);
    app_dummy();  // Keep ANativeActivity_onCreate from being stripped (ref: android/ndk#381)

    redirect_stdout_to_logcat();

    int result = main(0, nullptr);
    LOGD("android_main() exit: %d", result);

    state->onAppCmd = HandleCmd;

    ANativeActivity_finish(state->activity);  // Exit immediately
    while (!state->destroyRequested) {
        android_poll_source* source = nullptr;
        auto result = ALooper_pollOnce(-1, nullptr, nullptr, (void**)&source);  // -1: wait indefinitely
        if (result == ALOOPER_POLL_ERROR) {
            LOGE("ALooper_pollOnce returned an error");
            std::abort();
        }
        if (source != nullptr) {
            source->process(state, source);
        }
    }
    LOGD("android_main() finished");
}
#endif
