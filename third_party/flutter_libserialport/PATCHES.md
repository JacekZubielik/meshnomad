# Local patches

Vendored from `flutter_libserialport` 0.6.0 (https://github.com/jpnurmi/flutter_libserialport),
which bundles `libserialport` (https://sigrok.org/wiki/Libserialport) as
`third_party/libserialport/*.c`. Two bugs in that vendored C source made the
package unusable on at least one real device (an ESP32-S3 native
USB-Serial/JTAG interface) and unsafe in general. Both patches are in
`third_party/libserialport/serialport.c`.

## 1. `sp_new_config()` never initializes `config->xon_xoff`

`struct sp_port_config` has 9 fields; `sp_new_config()` only sets 8 of them
to the "leave alone" sentinel (`-1`) after `malloc()` (not `calloc()`).
`xon_xoff` is left uninitialized, so a freshly-created `SerialPortConfig`
that never touches XON/XOFF can carry leftover heap garbage there. If that
garbage doesn't match a valid `enum sp_xonxoff` value, `set_config()`
rejects the *entire* config apply with `SP_ERR_ARG: "Invalid XON/XOFF
setting"` (surfaces in Dart as `SerialPortError: Invalid argument, errno =
22`) — even though the caller never asked to touch flow control. This is
non-deterministic: it depends on what happened to be on the heap at that
particular `malloc()` call, so it may not reproduce on every machine/run.

Confirmed via `LIBSERIALPORT_DEBUG=1` tracing down to the exact
`set_config returning SP_ERR_ARG: Invalid XON/XOFF setting` call.

Fix: initialize `config->xon_xoff = -1;` alongside the other 8 fields.

## 2. `sp_open()` leaks the fd (and its exclusive lock) on two failure paths

On Linux, `sp_open()` opens the fd, then calls `flock(fd, LOCK_EX|LOCK_NB)`
and `ioctl(fd, TIOCEXCL)`. If either fails, the function returns via
`RETURN_FAIL(...)` **without closing the fd it just opened** — unlike the
`get_config()` failure path a few lines below, which correctly calls
`sp_close(port)` first. Compounding this, `sp_free_port()` (called by the
Dart-level `SerialPort.dispose()`) never closes the fd at all — it only
frees heap-allocated strings and the struct itself.

Net effect: if `flock()`/`TIOCEXCL` ever fails after `open()` succeeds
(observed on the ESP32-S3 above, though not root-caused to a specific
system limitation), the fd and its OS-level exclusive lock leak for the
life of the process. Every subsequent `open()` of that port — from any
process, including a fresh attempt from the same app — fails with `EBUSY`
("Device or resource busy") forever, with no way to recover short of
killing the process. This was misdiagnosed at first as *the* root cause
(bug #1 above is what actually triggered it in practice), but it's a real,
separate defect worth hardening regardless of what triggers it.

Fix:
- `sp_open()`: `close(port->fd); port->fd = -1;` before `RETURN_FAIL(...)`
  on both the `flock()` and `TIOCEXCL` failure paths.
- `sp_free_port()`: defensively `close(port->fd)` if it's still `>= 0`
  before freeing the struct (belt-and-suspenders — safe because `port->fd`
  is always initialized to `-1` when the struct is created, so this never
  closes an unrelated fd).

## Provenance

Both bugs were root-caused in the meshcore-open project while migrating
its desktop USB transport from `flserial` to `flutter_libserialport`
(2026-08-08), diagnosed via `strace` and `LIBSERIALPORT_DEBUG=1`. Not
reported upstream yet.
