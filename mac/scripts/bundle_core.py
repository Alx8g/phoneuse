#!/usr/bin/env python3
"""Builds the core that ships inside Phone Use.app (Contents/Resources/core), from this checkout and Homebrew.

    mac/scripts/bundle_core.py OUT_DIR

OUT_DIR gets:
  python/                  a relocatable CPython (python-build-standalone) with the core's modules and PyGObject
  phoneuse/ bin/ skill/    the core itself, as in the repository
  bin/uxplay               the AirPlay receiver (GPL-3.0, a separate program)
  bin/phoneuse-ocr         text recognition with Apple's Vision framework (mac/ocr/main.swift)
  lib/                     every Homebrew library these need, rewired to load from here (@rpath)
  lib/gstreamer-1.0/       the GStreamer plugins the hub, frames service and UxPlay use
  lib/girepository-1.0/    typelibs that load their libraries from lib/
  libexec/gst-plugin-scanner

Nothing in OUT_DIR points into /opt/homebrew afterwards; the script checks that at the end. Build-time needs:
Homebrew's gstreamer, pygobject3 (for Python 3.15), libplist and openssl@3, a UxPlay build (PHONEUSE_UXPLAY or
~/code/UxPlay/build/uxplay), and the network for the Python download and the Python modules.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
BREW = "/opt/homebrew"
PY_VERSION = "3.15"
PBS = ("https://github.com/astral-sh/python-build-standalone/releases/download/20261026/"
       "cpython-3.15.2%2B20261026-aarch64-apple-darwin-install_only.tar.gz")
CACHE = os.path.expanduser("~/Library/Caches/phoneuse-build")
MODULES = ["aiohttp", "numpy", "pillow", "bleak", "cryptography", "qrcode"]
# The plugins the pipelines use (hub.py, frames.py, web.py, UxPlay), by library name.
PLUGINS = ["coreelements", "app", "udp", "rtp", "rtpmanager", "videoparsersbad", "libav", "x264", "applemedia",
           "videoconvertscale", "videorate", "osxaudio", "audioconvert", "audioresample", "autodetect", "typefindfunctions",
           "playback", "audioparsers", "volume", "isomp4", "opus", "aac", "voaacenc", "fdkaac", "dtls", "srtp",
           "pbtypes", "rawparse", "videotestsrc", "audiotestsrc", "jpeg", "png", "debugutilsbad",
           "level", "imagefreeze", "videofilter", "pango"]  # the last four: UxPlay's audio and cover-art pipelines
TYPELIBS = ["GLib-2.0", "GObject-2.0", "Gio-2.0", "GModule-2.0", "GioUnix-2.0", "GLibUnix-2.0", "Gst-1.0",
            "GstBase-1.0", "GstApp-1.0", "GstVideo-1.0", "GstAudio-1.0", "GstRtp-1.0", "GstPbutils-1.0",
            "GstTag-1.0", "GstNet-1.0"]


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def fetch(url):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, os.path.basename(url).replace("%2B", "+"))
    if not os.path.exists(path):
        print("downloading", url)
        urllib.request.urlretrieve(url, path + ".part")
        os.rename(path + ".part", path)
    return path


def deps(path):
    """The libraries a Mach-O file links, as otool prints them."""
    out = subprocess.run(["otool", "-L", path], capture_output=True, text=True).stdout.splitlines()[1:]
    return [line.strip().split(" (")[0] for line in out if line.strip()]


def is_macho(path):
    with open(path, "rb") as f:
        return f.read(4) in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe")


class Bundle:
    def __init__(self, out):
        self.out = out
        self.lib = os.path.join(out, "lib")
        self.copied = {}  # real source path -> name in lib/

    def resolve(self, ref, origin):
        """A dependency's file on disk, or None for the system's own (/usr/lib, /System)."""
        if ref.startswith(("/usr/lib/", "/System/")):
            return None
        if ref.startswith("@rpath/") or ref.startswith("@loader_path/"):
            name = ref.split("/", 1)[1]
            for d in (os.path.dirname(origin), f"{BREW}/lib", os.path.join(self.lib)):
                p = os.path.join(d, name)
                if os.path.exists(p):
                    return os.path.realpath(p)
            return None
        return os.path.realpath(ref) if os.path.exists(ref) else None

    def add_lib(self, src):
        """Copies a library into lib/ (once) with its own dependencies; returns its name there."""
        src = os.path.realpath(src)
        if src in self.copied:
            return self.copied[src]
        name = os.path.basename(src)
        # keep the name the libraries link it by (libfoo.1.dylib), not the versioned file it points to
        self.copied[src] = name
        dst = os.path.join(self.lib, name)
        shutil.copy2(src, dst)
        os.chmod(dst, 0o755)
        run("install_name_tool", "-id", f"@rpath/{name}", dst, stderr=subprocess.DEVNULL)
        self.relink(dst, src, rpath="@loader_path")
        return name

    def relink(self, path, origin, rpath):
        """Points every non-system dependency of path at lib/ (copying it there), and adds rpath."""
        for ref in deps(path):
            if ref.startswith("@rpath/") and os.path.exists(os.path.join(self.lib, ref[7:])):
                continue
            src = self.resolve(ref, origin)
            if not src:
                continue
            if os.path.basename(src) == os.path.basename(path):
                continue  # its own id line
            name = self.add_lib_named(src, ref)
            run("install_name_tool", "-change", ref, f"@rpath/{name}", path, stderr=subprocess.DEVNULL)
        existing = subprocess.run(["otool", "-l", path], capture_output=True, text=True).stdout
        for old in re.findall(r"path (/opt/homebrew\S*) \(offset", existing):
            subprocess.run(["install_name_tool", "-delete_rpath", old, path], stderr=subprocess.DEVNULL)
        if f"path {rpath} " not in existing:
            subprocess.run(["install_name_tool", "-add_rpath", rpath, path], stderr=subprocess.DEVNULL)

    def add_lib_named(self, src, ref):
        """Copies src, named after the reference that links it (libglib-2.0.0.dylib, not its versioned file)."""
        name = os.path.basename(ref)
        dst = os.path.join(self.lib, name)
        if os.path.exists(dst):
            return name
        shutil.copy2(src, dst)
        os.chmod(dst, 0o755)
        run("install_name_tool", "-id", f"@rpath/{name}", dst, stderr=subprocess.DEVNULL)
        self.relink(dst, src, rpath="@loader_path")
        return name


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "mac", "build", "core"))
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(os.path.join(out, "lib", "gstreamer-1.0"))
    b = Bundle(out)

    # Python, its modules, and PyGObject (Homebrew's build for the same Python version)
    with tarfile.open(fetch(PBS)) as t:
        t.extractall(out, filter="data")
    py = os.path.join(out, "python", "bin", f"python{PY_VERSION}")
    run(py, "-m", "pip", "install", "-q", "--disable-pip-version-check", "--no-compile", *MODULES)
    site = os.path.join(out, "python", "lib", f"python{PY_VERSION}", "site-packages")
    gi_src = glob.glob(f"{BREW}/Cellar/pygobject3/*/lib/python{PY_VERSION}/site-packages/gi")[0]
    shutil.copytree(gi_src, os.path.join(site, "gi"))
    for so in glob.glob(os.path.join(site, "gi", "*.so")):
        b.relink(so, so, rpath=f"@loader_path/{os.path.relpath(b.lib, os.path.dirname(so))}")

    # GStreamer plugins and the plugin scanner
    plugdir = f"{BREW}/lib/gstreamer-1.0"
    missing = []
    for p in PLUGINS:
        src = os.path.join(plugdir, f"libgst{p}.dylib")
        if not os.path.exists(src):
            missing.append(p)
            continue
        dst = os.path.join(b.lib, "gstreamer-1.0", os.path.basename(src))
        shutil.copy2(src, dst)
        os.chmod(dst, 0o755)
        run("install_name_tool", "-id", f"@rpath/gstreamer-1.0/{os.path.basename(src)}", dst,
            stderr=subprocess.DEVNULL)
        b.relink(dst, os.path.realpath(src), rpath="@loader_path/..")
    if missing:
        print("plugins not in Homebrew (skipped):", ", ".join(missing))
    os.makedirs(os.path.join(out, "libexec"))
    scanner = os.path.join(out, "libexec", "gst-plugin-scanner")
    shutil.copy2(glob.glob(f"{BREW}/opt/gstreamer/libexec/gstreamer-1.0/gst-plugin-scanner")[0], scanner)
    b.relink(scanner, scanner, rpath="@loader_path/../lib")
    for name in ("libgirepository-2.0.0.dylib", "libgirepository-1.0.1.dylib"):  # PyGObject loads it by name
        if os.path.exists(f"{BREW}/lib/{name}") and not os.path.exists(os.path.join(b.lib, name)):
            b.add_lib_named(os.path.realpath(f"{BREW}/lib/{name}"), name)

    # Typelibs whose libraries load from lib/ (GIRepository dlopens them by these names)
    tdir = os.path.join(b.lib, "girepository-1.0")
    os.makedirs(tdir)
    compiler = shutil.which("gi-compile-repository") or shutil.which("g-ir-compiler")
    for ns in TYPELIBS:
        gir = f"{BREW}/share/gir-1.0/{ns}.gir"
        if not os.path.exists(gir):
            continue
        text = open(gir).read()

        def local(m):
            names = []
            for lib in m.group(1).split(","):
                name = os.path.basename(lib)
                src = os.path.join(BREW, "lib", name)
                if os.path.exists(src):
                    b.add_lib_named(os.path.realpath(src), name)
                names.append(f"@rpath/{name}")
            return f'shared-library="{",".join(names)}"'
        text = re.sub(r'shared-library="([^"]+)"', local, text)
        tmp = os.path.join(tdir, ns + ".gir")
        with open(tmp, "w") as f:
            f.write(text)
        run(compiler, "--includedir", f"{BREW}/share/gir-1.0", tmp, "-o", os.path.join(tdir, ns + ".typelib"))
        os.remove(tmp)

    # UxPlay
    os.makedirs(os.path.join(out, "bin"), exist_ok=True)
    ux = os.environ.get("PHONEUSE_UXPLAY") or os.path.expanduser("~/code/UxPlay/build/uxplay")
    shutil.copy2(ux, os.path.join(out, "bin", "uxplay"))
    b.relink(os.path.join(out, "bin", "uxplay"), ux, rpath="@loader_path/../lib")

    # Text recognition with Apple's Vision framework (phoneuse/vision.py runs it): no OCR model to ship
    run("swiftc", "-O", "-target", "arm64-apple-macos15", os.path.join(REPO, "mac", "ocr", "main.swift"),
        "-o", os.path.join(out, "bin", "phoneuse-ocr"))

    # The core
    for d in ("phoneuse", "skill"):
        shutil.copytree(os.path.join(REPO, d), os.path.join(out, d),
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    for f in ("phoneuse", "phoneuse-mcp"):
        shutil.copy2(os.path.join(REPO, "bin", f), os.path.join(out, "bin", f))

    # Nothing may still point into Homebrew
    bad = []
    for root, _dirs, files in os.walk(out):
        for f in files:
            p = os.path.join(root, f)
            if os.path.islink(p) or not os.path.isfile(p) or not is_macho(p):
                continue
            bad += [f"{p}: {r}" for r in deps(p) if r.startswith(BREW)]
    if bad:
        print("\n".join(bad[:20]))
        sys.exit("libraries still point into Homebrew")
    size = subprocess.run(["du", "-sh", out], capture_output=True, text=True).stdout.split()[0]
    print(f"core in {out} ({size}, {len(os.listdir(b.lib))} libraries)")


if __name__ == "__main__":
    main()
