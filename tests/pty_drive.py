#!/usr/bin/env python3
"""Drive v2raysetup.sh through a real pseudo-terminal (arrow keys, space, enter).

usage: pty_drive.py SCRIPT [args...]   — steps are read from the STEPS env (JSON):
  [["wait-text", "keys"], ...]  keys: \\x1b[B = down, " " = space, "\\r" = enter
Exits 0 when the program ends with code 0 and all waits matched.
"""
import json, os, pty, re, select, sys, time

ANSI = re.compile(rb'\x1b\[[0-9;?]*[A-Za-z]')

def main():
    steps = json.loads(os.environ["STEPS"])
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.environ["COLUMNS"] = "90"
        os.execvp("bash", ["bash"] + sys.argv[1:])
    buf = b""
    def read_until(pat, timeout=40):
        nonlocal buf
        end = time.time() + timeout
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.2)
            if r:
                try:
                    data = os.read(fd, 65536)
                except OSError:
                    return False
                if not data:
                    return False
                buf += data
            if pat.encode() in ANSI.sub(b"", buf):
                return True
        return False
    for wait, keys in steps:
        if not read_until(wait):
            print("TIMEOUT waiting for:", wait)
            print(ANSI.sub(b"", buf)[-3000:].decode(errors="replace"))
            os.kill(pid, 9); sys.exit(1)
        buf_mark = len(buf)
        time.sleep(0.3)
        for ch in [keys]:
            os.write(fd, ch.encode())
    # drain
    end = time.time() + 60
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.3)
        if r:
            try:
                d = os.read(fd, 65536)
            except OSError:
                break
            if not d:
                break
            buf += d
    _, status = os.waitpid(pid, 0)
    sys.stdout.write(buf.decode(errors="replace"))
    code = os.waitstatus_to_exitcode(status)
    print(f"\n[pty_drive] exit code {code}")
    sys.exit(code)

main()
