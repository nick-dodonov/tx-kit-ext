#include "droid_argv.h"

#include <stdlib.h>
#include <string.h>

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

/// Get argv string from DroidActivity.getArgvString(). Returns 1 if found, 0 on failure.
static int get_from_activity(ANativeActivity* activity, JNIEnv* env, int* out_argc, char*** out_argv)
{
    jclass clazz = env->GetObjectClass(activity->clazz);
    if (!clazz) return 0;
    jmethodID getArgvString = env->GetMethodID(clazz, "getArgvString", "()Ljava/lang/String;");
    if (!getArgvString) return 0;
    jstring jstr = (jstring)env->CallObjectMethod(activity->clazz, getArgvString);
    if (!jstr) return 0;
    const char* utf = env->GetStringUTFChars(jstr, nullptr);
    if (!utf) {
        env->DeleteLocalRef(jstr);
        return 0;
    }
    parse_argv_string(utf, out_argc, out_argv);
    env->ReleaseStringUTFChars(jstr, utf);
    env->DeleteLocalRef(jstr);
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

DroidArgv::DroidArgv(ANativeActivity* activity, JNIEnv* env)
{
    if (!get_from_activity(activity, env, &argc_, &argv_)) {
        fallback(&argc_, &argv_);
    }
}

DroidArgv::~DroidArgv()
{
    free_argv(argc_, argv_);
}
