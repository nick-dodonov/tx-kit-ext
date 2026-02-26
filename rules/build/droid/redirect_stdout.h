// Redirects stdout and stderr to Android logcat via __android_log_write.
// Call at startup before any printf/cout; output appears with tag "stdout".
void redirect_stdout_to_logcat(void);
