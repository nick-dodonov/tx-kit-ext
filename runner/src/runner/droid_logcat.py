'''
TODO:
## Binary (`-B`)

Format is described in AOSP and implemented in `@yume-chan/android-bin` (ya-webadb).

**Record structure:**

1. **Header** (`log_read.h` / `logger_entry`):
   - `payloadSize` (u16) — payload size
   - `headerSize` (u16) — header size
   - `pid`, `tid` (u32)
   - `seconds`, `nanoseconds` (u32)
   - `logId` (u32) — buffer (Main=0, System=3, …)
   - `uid` (u32)

2. **Payload** (`logprint.cpp`):
   - 1 byte — priority (0–8: Unknown, Default, V, D, I, W, E, F, Silent)
   - tag — UTF-8, up to `\0`, space or `:`
   - message — rest of payload

**Parsing:**

- **TypeScript/JS:** `@yume-chan/android-bin` — `Logcat.binary()` returns `ReadableStream<AndroidLogEntry>`.
- **Python:** no ready-made library exists, but the format is simple — can be implemented based on this structure.
- **Go:** there are parsers like gocat (usually work with text output).

---

## Protobuf (`--proto`)

Format is almost undocumented. Known facts:

- **Perfetto** uses `AndroidLogPacket` for logs in traces — this is a different format, not direct output from `adb logcat --proto`.
- **ProtoLog** — separate system for WindowManager etc., not general logcat.
- Exact `.proto` schema for `adb logcat --proto` is not found in public repositories.

**Practical options:**

1. **Perfetto** — if you need logs in traces: `android.log` data source, `AndroidLogConfig`, `AndroidLogPacket`.
2. **Binary format parsing** — `protoc --decode_raw` on the stream to see the structure.
3. **Search in AOSP** — `logcat.cpp` and `log_read.h` in `platform/system/core`.

---

## Recommendation

For programmatic parsing, it's more logical to use **binary** (`-B`): the format is known, there's a working parser in `@yume-chan/android-bin`, and the structure is simple to implement in other languages. The protobuf format is better avoided until the schema is found.
'''
