#include "redirect_stdout.h"
#include <android/log.h>
#include <pthread.h>
#include <unistd.h>
#include <cstdio>

static int s_pfd[2];
static pthread_t s_logging_thread;
static const char* s_stdout_tag = "stdout";

static void* logging_thread_func(void*) {
    char buf[256];
    ssize_t n;
    while ((n = read(s_pfd[0], buf, sizeof(buf) - 1)) > 0) {
        if (buf[n - 1] == '\n') {
            --n;
        }
        buf[n] = '\0';
        __android_log_write(ANDROID_LOG_INFO, s_stdout_tag, buf);
    }
    return nullptr;
}

void redirect_stdout_to_logcat(void) {
    setvbuf(stdout, nullptr, _IOLBF, 0);
    setvbuf(stderr, nullptr, _IONBF, 0);
    pipe(s_pfd);
    dup2(s_pfd[1], STDOUT_FILENO);
    dup2(s_pfd[1], STDERR_FILENO);
    pthread_create(&s_logging_thread, nullptr, logging_thread_func, nullptr);
    pthread_detach(s_logging_thread);
}
