# Banked SRAM Low-Power Extension

This extension adds a banked behavioral SRAM variant with independent bank clocks and an always-on per-bank power controller.

## Implemented architecture

- Four independently managed banks by default, selected by low-order address bits.
- ACTIVE, SLEEP, and WAKE states per bank.
- Per-bank idle timeout and parameterized wake-up latency.
- Latch-based ICG model per bank; only the requested bank is clocked during an access.
- Retention-save and retention-restore request pulses.
- Memory contents are not reset by the bank controller, so the behavioral array preserves data across SLEEP.
- A single accepted request is either a read or a write. This example does not implement simultaneous read/write concurrency.

## Run

From the repository root:

    make -C low_power test

The self-checking test writes and reads words in different banks, waits for idle-bank sleep, wakes banks on demand, verifies retention readback, and checks that accessing one bank does not wake another.

## Integration notes

The ICG is a behavioral model. Replace it with a characterized library ICG or use the SRAM macro's native clock-enable interface. Connect retention_save and retention_restore to the macro's retention controls where supported. The behavioral array does not model a foundry retention cell or power switch.

No physical power numbers or percentage savings are claimed. Use the bank clock-enable activity as a functional proxy, then run a library/macro-aware power analysis to quantify energy.
