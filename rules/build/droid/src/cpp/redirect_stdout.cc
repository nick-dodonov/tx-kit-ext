#include "redirect_stdout.h"
#include <android/log.h>
#include <cstdio>
#include <iostream>
#include <streambuf>

// Synchronous redirection: funopen for printf, custom streambuf for std::cout.
// Both run in the same thread as the caller (no pipe/thread).

static constexpr int kLineBufSize = 512;

// --- funopen for printf/fprintf(stdout) ---
struct LogCookie {
  const char* tag;
  int level;
  char line_buf[kLineBufSize];
  int line_len = 0;
};

static void flush_line(LogCookie* c) {
  if (c->line_len <= 0) return;
  c->line_buf[c->line_len] = '\0';
  __android_log_write(c->level, c->tag, c->line_buf);
  c->line_len = 0;
}

static int logcat_write(void* cookie, const char* buf, int size) {
  auto* c = static_cast<LogCookie*>(cookie);
  for (int i = 0; i < size; ++i) {
    char ch = buf[i];
    if (ch == '\n' || ch == '\r') {
      flush_line(c);
    } else if (c->line_len < kLineBufSize - 1) {
      c->line_buf[c->line_len++] = ch;
    }
  }
  return size;
}

static int logcat_close(void* cookie) {
  flush_line(static_cast<LogCookie*>(cookie));
  return 0;
}

static LogCookie s_stdout_cookie = {"stdout", ANDROID_LOG_INFO, {}, 0};
static LogCookie s_stderr_cookie = {"stderr", ANDROID_LOG_WARN, {}, 0};

// --- custom streambuf for std::cout / std::cerr ---
class LogcatStreambuf : public std::streambuf {
 public:
  LogcatStreambuf(const char* tag, int level) : tag_(tag), level_(level) {
    setp(buf_, buf_ + kLineBufSize - 1);
  }

 protected:
  int overflow(int c) override {
    if (c != traits_type::eof()) {
      if (pptr() >= epptr()) sync();
      *pptr() = static_cast<char>(c);
      pbump(1);
      if (c == '\n' || c == '\r') sync();
    }
    return c;
  }

  int sync() override {
    if (pptr() > pbase()) {
      size_t n = pptr() - pbase();
      if (n > 0 && buf_[n - 1] == '\n') --n;
      if (n > 0) {
        buf_[n] = '\0';
        __android_log_write(level_, tag_, buf_);
      }
      setp(buf_, buf_ + kLineBufSize - 1);
    }
    return 0;
  }

 private:
  const char* tag_;
  int level_;
  char buf_[kLineBufSize];
};

static LogcatStreambuf s_cout_buf("stdout", ANDROID_LOG_INFO);
static LogcatStreambuf s_cerr_buf("stderr", ANDROID_LOG_WARN);

void redirect_stdout_to_logcat(void) {
  // 1. funopen: printf/fprintf(stdout) -> logcat
  FILE* out = funopen(&s_stdout_cookie, nullptr, logcat_write, nullptr, logcat_close);
  FILE* err = funopen(&s_stderr_cookie, nullptr, logcat_write, nullptr, logcat_close);
  if (out && err) {
    setvbuf(out, nullptr, _IOLBF, 0);
    setvbuf(err, nullptr, _IONBF, 0);
    fclose(stdout);
    fclose(stderr);
    stdout = out;
    stderr = err;
  }

  // 2. streambuf: std::cout / std::cerr -> logcat (writes to fd 1/2 otherwise)
  std::cout.rdbuf(&s_cout_buf);
  std::cerr.rdbuf(&s_cerr_buf);
}
