#include "droid_argv.h"

#include <jni.h>
#include <stdlib.h>
#include <string.h>

#include "droid_log.h"

static const char* TX_ARGV_EXTRA = "tx.argv";

/// Parse space-separated string into argc/argv. Always includes argv[0]="app". Caller must free.
static void parse_argv_string(const char* str, int* out_argc, char*** out_argv)
{
    int n = 0;
    if (str && *str) {
        const char* p = str;
        while (*p) {
            while (*p == ' ') p++;
            if (!*p) break;
            n++;
            while (*p && *p != ' ') p++;
        }
    }
    char** argv = (char**)malloc((n + 2) * sizeof(char*));
    if (!argv) {
        *out_argc = 0;
        *out_argv = nullptr;
        return;
    }
    argv[0] = strdup("app");
    int i = 1;
    if (str && *str) {
        const char* p = str;
        while (*p && i <= n) {
            while (*p == ' ') p++;
            if (!*p) break;
            const char* start = p;
            while (*p && *p != ' ') p++;
            size_t len = (size_t)(p - start);
            argv[i] = (char*)malloc(len + 1);
            if (argv[i]) {
                memcpy(argv[i], start, len);
                argv[i][len] = '\0';
            }
            i++;
        }
    }
    *out_argc = i;
    *out_argv = argv;
}

/// Get tx.argv from Intent via JNI. Returns 1 if found, 0 on failure.
static int get_from_intent(ANativeActivity* activity, int* out_argc, char*** out_argv)
{
    JNIEnv* env = nullptr;
    if (activity->vm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
        LOGW("AttachCurrentThread failed");
        return 0;
    }
    jobject me = activity->clazz;
    jclass acl = env->GetObjectClass(me);
    if (!acl) {
        LOGW("GetObjectClass failed");
        return 0;
    }
    jmethodID getIntent = env->GetMethodID(acl, "getIntent", "()Landroid/content/Intent;");
    if (!getIntent) {
        LOGW("GetMethodID getIntent failed");
        return 0;
    }
    jobject intent = env->CallObjectMethod(me, getIntent);
    if (!intent) {
        LOGW("getIntent() returned null");
        return 0;
    }
    jclass icl = env->GetObjectClass(intent);
    if (!icl) return 0;
    jmethodID getStringExtra = env->GetMethodID(icl, "getStringExtra", "(Ljava/lang/String;)Ljava/lang/String;");
    if (!getStringExtra) {
        LOGW("GetMethodID getStringExtra failed");
        return 0;
    }
    jstring key = env->NewStringUTF(TX_ARGV_EXTRA);
    if (!key) return 0;
    jstring jstr = (jstring)env->CallObjectMethod(intent, getStringExtra, key);
    env->DeleteLocalRef(key);
    if (!jstr) {
        LOGW("getStringExtra(tx.argv) returned null");
        return 0;
    }
    const char* utf = env->GetStringUTFChars(jstr, nullptr);
    if (!utf) {
        env->DeleteLocalRef(jstr);
        return 0;
    }
    parse_argv_string(utf, out_argc, out_argv);
    env->ReleaseStringUTFChars(jstr, utf);
    env->DeleteLocalRef(jstr);
    LOGW("droid_argv_from_intent: argc=%d", *out_argc);
    return 1;
}

static void free_argv(int argc, char** argv)
{
    if (!argv) return;
    for (int i = 0; i < argc; i++) {
        free(argv[i]);
    }
    free(argv);
}

/// Fallback when Intent has no tx.argv.
static void fallback(int* out_argc, char*** out_argv)
{
    *out_argc = 1;
    *out_argv = (char**)malloc(2 * sizeof(char*));
    if (*out_argv) {
        (*out_argv)[0] = strdup("app");
        (*out_argv)[1] = nullptr;
    }
}

DroidArgv::DroidArgv(ANativeActivity* activity)
{
    if (!get_from_intent(activity, &argc_, &argv_)) {
        fallback(&argc_, &argv_);
    }
}

DroidArgv::~DroidArgv()
{
    free_argv(argc_, argv_);
}
