#!/usr/bin/env python3
"""Run the Prime-OS ISO build behind a single progress bar.

The full, noisy container output goes to ``build.log``; the console shows one
updating bar with the current stage. On a terminal the bar redraws in place, and
in CI logs (no TTY) exactly one line is printed per stage, so the job log stays
readable instead of showing thousands of package lines.

On failure the last lines of the log are printed and the exit code is preserved.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

# (keywords that mark the start of a stage, start percent, human label)
STAGES: tuple[tuple[tuple[str, ...], float, str], ...] = (
    (("installing packages", "pacstrap", "pacman -s"), 6.0, "installing packages"),
    (("copying airootfs", "copying custom airootfs", "airootfs"), 30.0, "building the live filesystem"),
    (("creating squashfs", "mksquashfs", "squashfs image"), 45.0, "compressing the filesystem"),
    (("creating iso", "xorriso", "el torito", "creating a bootable"), 88.0, "writing the ISO image"),
)
BAR_WIDTH = 28
TAIL_LINES = 80


def stage_for(line: str, current: int) -> int:
    """Return the furthest stage index matched by ``line``."""
    lowered = line.lower()
    for index, (keywords, _start, _label) in enumerate(STAGES):
        if index > current and any(keyword in lowered for keyword in keywords):
            current = index
    return current


def paint(percent: float, label: str) -> str:
    filled = max(0, min(BAR_WIDTH, int(round(percent / 100.0 * BAR_WIDTH))))
    return f"  {'█' * filled}{'░' * (BAR_WIDTH - filled)} {percent:5.1f}%  {label}"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Build the ISO behind one progress bar.")
    parser.add_argument("--log", default="build.log", help="where the full build output is written")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="command to run (after --)")
    args = parser.parse_args(argv)

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("no build command given; pass it after --")

    tty = sys.stdout.isatty()
    log_path = Path(args.log)
    stage = 0
    started = time.monotonic()
    stage_started = started
    last_render = 0.0

    print("Prime-OS ISO build", flush=True)
    print(paint(STAGES[0][1], STAGES[0][2]), flush=True)

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
        )
        assert process.stdout is not None
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                found = stage_for(line, stage)
                if found != stage:
                    stage, stage_started = found, time.monotonic()
                    stage_line = paint(STAGES[stage][1], STAGES[stage][2])
                    if tty:  # replace the bar instead of starting a new line
                        sys.stdout.write("\r\x1b[2K" + stage_line)
                        sys.stdout.flush()
                    else:  # one readable line per stage in CI logs
                        print(stage_line, flush=True)
                now = time.monotonic()
                if tty and now - last_render > 0.5:
                    last_render = now
                    base, label = STAGES[stage][1], STAGES[stage][2]
                    ceiling = STAGES[stage + 1][1] - 2.0 if stage + 1 < len(STAGES) else 99.0
                    creep = min(ceiling, base + (now - stage_started) * 0.25)
                    sys.stdout.write("\r\x1b[2K" + paint(creep, label))
                    sys.stdout.flush()
            code = process.wait()
        except KeyboardInterrupt:
            process.terminate()
            process.wait(timeout=30)
            code = 130

    elapsed = time.monotonic() - started
    if code == 0:
        final = paint(100.0, f"done in {elapsed / 60:.1f} min")
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
