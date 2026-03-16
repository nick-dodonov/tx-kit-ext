#pragma once

struct ANativeActivity;

// Global pointer to ANativeActivity, available after ANativeActivity_onCreate
extern ANativeActivity* g_NativeActivity;
