#!/usr/bin/env python3
"""Find base64-encoded ARTEMIS{...} flags. Usage: findflags.py [paths...]"""
import base64, os, re, sys

MARK = b"ARTEMIS{"
B64 = re.compile(rb'[A-Za-z0-9+/]{12,}={0,2}')
SKIP_DIRS = {'/proc', '/sys', '/dev', '/run', '/snap'}
SKIP_EXT = {'.so', '.o', '.pyc', '.gz', '.xz', '.zip', '.jpg', '.png', '.gif',
            '.woff', '.woff2', '.ttf', '.ico', '.mp4', '.deb', '.img'}
MAXSIZE = 8 * 1024 * 1024

roots = sys.argv[1:] or ['/etc', '/var/www', '/home', '/root', '/opt',
                         '/srv', '/usr/local', '/tmp', '/var/backups']
hits = 0

def scan(path):
    global hits
    try:
        if os.path.getsize(path) > MAXSIZE:
            return
        with open(path, 'rb') as fh:
            data = fh.read()
    except Exception:
        return
    seen = set()
    for m in B64.finditer(data):
        tok = m.group()
        # the flag may not start on a 4-char boundary, so slide the offset
        for off in range(4):
            sub = tok[off:].rstrip(b'=')
            if len(sub) < 12:
                break
            rem = len(sub) % 4
            if rem == 1:            # impossible length, drop a char
                sub = sub[:-1]
                rem = len(sub) % 4
            if rem:                 # pad the tail rather than truncating it
                sub += b'=' * (4 - rem)
            try:
                dec = base64.b64decode(sub)
            except Exception:
                continue
            if MARK not in dec:
                continue
            flag = re.search(rb'ARTEMIS\{[^}]*\}', dec)
            flag = flag.group().decode() if flag else dec[:80].decode('utf-8', 'replace')
            if (path, flag) in seen:
                continue
            seen.add((path, flag))
            line = data[:m.start()].count(b'\n') + 1
            print(f"{path}:{line}: {flag}")
            print(f"    encoded: {tok.decode()}")
            hits += 1

for root in roots:
    if not os.path.exists(root):
        continue
    if os.path.isfile(root):
        scan(root)
        continue
    for dirpath, dirnames, filenames in os.walk(root, onerror=lambda e: None):
        if any(dirpath.startswith(s) for s in SKIP_DIRS):
            dirnames[:] = []
            continue
        for name in filenames:
            if os.path.splitext(name)[1].lower() in SKIP_EXT:
                continue
            p = os.path.join(dirpath, name)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            scan(p)

print(f"\n{hits} flag(s) found.", file=sys.stderr)#!/usr/bin/env python3
"""Find base64-encoded ARTEMIS{...} flags. Usage: findflags.py [paths...]"""
import base64, os, re, sys

MARK = b"ARTEMIS{"
B64 = re.compile(rb'[A-Za-z0-9+/]{12,}={0,2}')
SKIP_DIRS = {'/proc', '/sys', '/dev', '/run', '/snap'}
SKIP_EXT = {'.so', '.o', '.pyc', '.gz', '.xz', '.zip', '.jpg', '.png', '.gif',
            '.woff', '.woff2', '.ttf', '.ico', '.mp4', '.deb', '.img'}
MAXSIZE = 8 * 1024 * 1024

roots = sys.argv[1:] or ['/etc', '/var/www', '/home', '/root', '/opt',
                         '/srv', '/usr/local', '/tmp', '/var/backups']
hits = 0

def scan(path):
    global hits
    try:
        if os.path.getsize(path) > MAXSIZE:
            return
        with open(path, 'rb') as fh:
            data = fh.read()
    except Exception:
        return
    seen = set()
    for m in B64.finditer(data):
        tok = m.group()
        # the flag may not start on a 4-char boundary, so slide the offset
        for off in range(4):
            sub = tok[off:].rstrip(b'=')
            if len(sub) < 12:
                break
            rem = len(sub) % 4
            if rem == 1:            # impossible length, drop a char
                sub = sub[:-1]
                rem = len(sub) % 4
            if rem:                 # pad the tail rather than truncating it
                sub += b'=' * (4 - rem)
            try:
                dec = base64.b64decode(sub)
            except Exception:
                continue
            if MARK not in dec:
                continue
            flag = re.search(rb'ARTEMIS\{[^}]*\}', dec)
            flag = flag.group().decode() if flag else dec[:80].decode('utf-8', 'replace')
            if (path, flag) in seen:
                continue
            seen.add((path, flag))
            line = data[:m.start()].count(b'\n') + 1
            print(f"{path}:{line}: {flag}")
            print(f"    encoded: {tok.decode()}")
            hits += 1

for root in roots:
    if not os.path.exists(root):
        continue
    if os.path.isfile(root):
        scan(root)
        continue
    for dirpath, dirnames, filenames in os.walk(root, onerror=lambda e: None):
        if any(dirpath.startswith(s) for s in SKIP_DIRS):
            dirnames[:] = []
            continue
        for name in filenames:
            if os.path.splitext(name)[1].lower() in SKIP_EXT:
                continue
            p = os.path.join(dirpath, name)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            scan(p)

print(f"\n{hits} flag(s) found.", file=sys.stderr)
