#!/usr/bin/env python3
"""Run the Prime-OS ISO build behind a single progress bar.

The full, noisy container output goes to ``build.log``; the console shows one
bar with the current stage, the elapsed time and a short hint of the newest log
line.

* On a terminal the bar redraws in place about twice a second.
* In a CI log (no TTY) it prints one line per stage change **and one line per
  heartbeat**, from an independent timer — so a quiet stage (``mksquashfs``
  compressing several GiB can take 20+ minutes without printing much) still
  shows the bar moving instead of looking hung, and the log never floods.

On failure the last lines of the log are printed and the exit code is preserved.
``Ctrl+C`` terminates the whole process group, so no container is left behind.
"""
from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

# (keywords that start the stage, percent at that moment, human label).
# A stage's ceiling is the next stage's start, so the bar keeps creeping forward
# inside a long stage instead of freezing.
STAGES: tuple[tuple[tuple[str, ...], float, str], ...] = (
    (("installing packages", "pacstrap"), 4.0, "installing packages"),
    (("copying custom airootfs", "copying /etc/skel", "copying /boot"), 24.0,
     "assembling the live filesystem"),
    (("creating squashfs", "creating erofs", "mksquashfs"), 30.0,
     "compressing the filesystem (the long step)"),
    (("creating iso image", "writing the iso", "el torito"), 86.0, "writing the ISO image"),
    (("creating checksum", "signing rootfs"), 96.0, "checksums and signing"),
)
BAR_WIDTH = 24
TAIL_LINES = 80
HINT_CHARS = 90
CREEP_PER_SECOND = 0.4


class Board:
    """Thread-safe-enough shared state for the bar and the heartbeat timer."""

    def __init__(self) -> None:
        self.stage = 0
        self.started = time.monotonic()
        self.stage_started = self.started
        self.hint = ""
        self.stopped = False
        self.lock = threading.Lock()

    def percent(self) -> float:
        base = STAGES[self.stage][1]
        ceiling = STAGES[self.stage + 1][1] - 1.0 if self.stage + 1 < len(STAGES) else 99.0
        return min(ceiling, base + (time.monotonic() - self.stage_started) * CREEP_PER_SECOND)

    def label(self) -> str:
        return STAGES[self.stage][2]

    def elapsed(self) -> float:
        return time.monotonic() - self.started


def paint(percent: float, label: str, elapsed: float, hint: str = "") -> str:
    filled = max(0, min(BAR_WIDTH, int(round(percent / 100.0 * BAR_WIDTH))))
    line = f"  {'█' * filled}{'░' * (BAR_WIDTH - filled)} {percent:5.1f}%  {label}  ·  {elapsed / 60:5.1f} min"
    if hint:
        line += f"  ·  last: {hint[:HINT_CHARS]}"
    return line


def hint_from(line: str) -> str:
    return " ".join(line.strip().split())


def terminate(process: subprocess.Popen) -> None:
    """Stop the whole process group so docker's children do not survive."""
    try:
        group = os.getpgid(process.pid)
    except OSError:
        return
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(group, sig)
        except OSError:
            return
        try:
            process.wait(timeout=15)
            return
        except subprocess.TimeoutExpired:
            continue


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Build the ISO behind one progress bar.")
    parser.add_argument("--log", default="build.log", help="where the full build output is written")
    parser.add_argument("--heartbeat", type=float, default=45.0,
                        help="seconds between bar updates in a non-interactive log")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="command to run (after --)")
    args = parser.parse_args(argv)

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("no build command given; pass it after --")

    tty = sys.stdout.isatty()
    interval = 0.5 if tty else max(5.0, args.heartbeat)
    board = Board()
    log_path = Path(args.log)
    write_lock = threading.Lock()

    def show() -> None:
        with write_lock:
            line = paint(board.percent(), board.label(), board.elapsed(), board.hint)
            if tty:
                sys.stdout.write("\r\x1b[2K" + line)
            else:
                print(line, flush=True)
            sys.stdout.flush()

    def heartbeat() -> None:
        while not board.stopped:
            time.sleep(interval)
            if not board.stopped:
                show()

    print("Prime-OS ISO build", flush=True)
    show()

    with log_path.open("w", encoding="utf-8", errors="replace") as log:
        log.write("$ " + " ".join(command) + "\n")
        log.flush()
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            bufsize=1,
            start_new_session=True,
        )
        assert process.stdout is not None
        ticker = threading.Thread(target=heartbeat, daemon=True)
        ticker.start()
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if not line.strip():
                    continue
                board.hint = hint_from(line)
                found = next(
                    (index for index, (keywords, _start, _label) in enumerate(STAGES)
                     if index > board.stage and any(k in line.lower() for k in keywords)),
                    board.stage,
                )
                if found != board.stage:
                    board.stage = found
                    board.stage_started = time.monotonic()
                    show()
            code = process.wait()
        except KeyboardInterrupt:
            terminate(process)
            code = 130
        finally:
            board.stopped = True
            ticker.join(timeout=1.0)

    elapsed = board.elapsed()
    with write_lock:
        if code == 0:
            final = paint(100.0, f"done in {elapsed / 60:.1f} min", elapsed)
            if tty:
                sys.stdout.write("\r\x1b[2K" + final + "\n")
            else:
                print(final, flush=True)
            print(f"Full build log: {log_path}", flush=True)
            return 0

        if tty:
            sys.stdout.write("\r\x1b[2K")
        print(f"\nBuild failed after {elapsed / 60:.1f} min (exit {code}).", flush=True)
        tail = log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-TAIL_LINES:]
        print(f"--- last {len(tail)} lines of {log_path} ---", flush=True)
        print("\n".join(tail), flush=True)
        return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
