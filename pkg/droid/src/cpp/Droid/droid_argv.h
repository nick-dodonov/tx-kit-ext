#pragma once
#include <android/native_activity.h>
#include <jni.h>

/// RAII holder for argc/argv from Intent (or fallback). Frees in destructor.
struct DroidArgv {
    DroidArgv(ANativeActivity* activity, JNIEnv* env);
    ~DroidArgv();

    DroidArgv(const DroidArgv&) = delete;
    DroidArgv& operator=(const DroidArgv&) = delete;

    int argc() const { return argc_; }
    char** argv() const { return argv_; }
    //const char** argv() const { return const_cast<const char**>(argv_); }

private:
    int argc_ = 0;
    char** argv_ = nullptr;
};
