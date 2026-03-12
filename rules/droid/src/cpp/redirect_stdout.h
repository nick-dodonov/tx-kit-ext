// Redirects stdout and stderr to Android logcat via __android_log_write.
// Call at startup before any printf/cout. Logging is synchronous (same thread).
// printf -> funopen; std::cout/cerr -> custom streambuf. Tags: "stdout", "stderr".
void redirect_stdout_to_logcat(void);
