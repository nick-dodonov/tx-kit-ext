#pragma once
#include <jni.h>

struct AAssetManager;

namespace Droid
{
    /// Interface providing access to main Android-specific resources and services (i.e. JNI environment or asset manager).
    class Glue
    {
        static Glue* _instance;

    protected:
        static void SetInternal(Glue* instance) { _instance = instance; } // TODO: error on multiple setup

    public:
        static Glue& Instance() { return *_instance; }

        virtual ~Glue() = default;

        [[nodiscard]] virtual JNIEnv* GetMainJNIEnv() const = 0;
        [[nodiscard]] virtual AAssetManager* GetAssetManager() const = 0;
    };
}
