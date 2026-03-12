'''
TODO:
## Binary (`-B`)

Формат описан в AOSP и реализован в `@yume-chan/android-bin` (ya-webadb).

**Структура записи:**

1. **Заголовок** (`log_read.h` / `logger_entry`):
   - `payloadSize` (u16) — размер payload
   - `headerSize` (u16) — размер заголовка
   - `pid`, `tid` (u32)
   - `seconds`, `nanoseconds` (u32)
   - `logId` (u32) — буфер (Main=0, System=3, …)
   - `uid` (u32)

2. **Payload** (`logprint.cpp`):
   - 1 байт — priority (0–8: Unknown, Default, V, D, I, W, E, F, Silent)
   - tag — UTF-8, до `\0`, пробела или `:`
   - message — остаток payload

**Парсинг:**

- **TypeScript/JS:** `@yume-chan/android-bin` — `Logcat.binary()` возвращает `ReadableStream<AndroidLogEntry>`.
- **Python:** готовой библиотеки нет, но формат простой — можно реализовать по этой структуре.
- **Go:** есть парсеры вроде gocat (обычно работают с текстовым выводом).

---

## Protobuf (`--proto`)

Формат почти не документирован. Известно:

- **Perfetto** использует `AndroidLogPacket` для логов в трейсах — это другой формат, не прямой вывод `adb logcat --proto`.
- **ProtoLog** — отдельная система для WindowManager и т.п., не общий logcat.
- Точная `.proto`-схема для `adb logcat --proto` в публичных репозиториях не найдена.

**Практические варианты:**

1. **Perfetto** — если нужны логи в трейсе: `android.log` data source, `AndroidLogConfig`, `AndroidLogPacket`.
2. **Разбор бинарного формата** — `protoc --decode_raw` по потоку, чтобы увидеть структуру.
3. **Поиск в AOSP** — `logcat.cpp` и `log_read.h` в `platform/system/core`.

---

## Рекомендация

Для программного парсинга логичнее использовать **binary** (`-B`): формат известен, есть рабочий парсер в `@yume-chan/android-bin`, структура простая для реализации на других языках. Protobuf-формат пока лучше обходить, пока не найдётся схема.
'''
