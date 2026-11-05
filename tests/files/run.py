#!/usr/bin/env python3
"""Files' focused GUI checks on a private headless Sway. Aka only.

Usage: run.py TESTS_BINARY APP_BINARY [--packaged]
Modes (HENSOU_FILES_TEST_MODES, comma separated; default all):
  suite    Qt Quick tests (tests/files/tst_*.qml), both themes
  capture  captures of every key state, both themes and modes, scale 1.5
  process  the real binary: daemon, single-instance handoff, residency, SNI
Evidence: /tmp/hensou-p35/evidence/files-<sha>[-packaged][-modes]/
"""

import json
import os
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

assert os.uname().nodename.split(".")[0] == "aka", "Aka only"
tests_binary, app_binary = sys.argv[1], sys.argv[2]
packaged = len(sys.argv) > 3 and sys.argv[3] == "--packaged"
all_modes = ["suite", "capture", "process"]
modes = [m for m in os.environ.get("HENSOU_FILES_TEST_MODES", ",".join(all_modes)).split(",") if m]
assert modes and set(modes) <= set(all_modes), modes
source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
suffix = ("-packaged" if packaged else "") + ("" if modes == all_modes else "-" + "-".join(modes))
evidence = Path("/tmp/hensou-p35/evidence") / f"files-{source}{suffix}"
if evidence.exists():
    shutil.rmtree(evidence)
evidence.mkdir(parents=True)
ack = Path("/tmp/hensou-files-capture/ack")
results = {"source": source, "packaged": packaged, "modes": modes, "phases": {}}


def log(message):
    print(message, flush=True)


with tempfile.TemporaryDirectory(prefix="hensou-files-") as temporary:
    base = Path(temporary)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    env = os.environ | {
        "XDG_RUNTIME_DIR": str(runtime),
        "XDG_STATE_HOME": str(base / "state"),
        "HOME": str(base / "home"),
        "WLR_BACKENDS": "headless",
        "WLR_HEADLESS_OUTPUTS": "1",
        "WLR_LIBINPUT_NO_DEVICES": "1",
        "WLR_RENDERER": "pixman",
        "WLR_RENDERER_ALLOW_SOFTWARE": "1",
        "LP_NUM_THREADS": "2",
        "QT_QPA_PLATFORM": "wayland",
        "LIBGL_ALWAYS_SOFTWARE": "1",
        "QSG_RHI_BACKEND": "opengl",
        "QT_WAYLAND_DISABLE_WINDOWDECORATION": "1",
        "QML_DISABLE_DISK_CACHE": "1",
        "QML_XHR_ALLOW_FILE_READ": "1",
        "HENSOU_FILES_HOSTNAME": "myoko",
        "HENSOU_FILES_BACKEND": "fixture",
        "TZ": "UTC",
    }
    (base / "home").mkdir()
    env.pop("QT_QUICK_BACKEND", None)
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    env.pop("DBUS_SESSION_BUS_ADDRESS", None)
    if packaged:
        for variable in ("LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH", "QT_PLUGIN_PATH",
                         "QT_QPA_PLATFORM_PLUGIN_PATH", "HENSOU_QML_IMPORT_PATH", "HENSOU_FONT_DIRECTORY"):
            env.pop(variable, None)
    config = base / "sway.conf"
    config.write_text("""output HEADLESS-1 mode 2400x1600 scale 1.5 position 0 0
seat seat0 fallback true
focus_follows_mouse no
default_border none
default_floating_border none
for_window [app_id=".*"] floating enable
""")
    bus_log = (evidence / "dbus.log").open("w")
    bus = subprocess.Popen(["dbus-daemon", "--session", "--nofork", "--nopidfile",
                            f"--address=unix:path={runtime / 'bus'}"], env=env, stdout=bus_log,
                           stderr=subprocess.STDOUT, start_new_session=True)
    env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={runtime / 'bus'}"
    sway_log = (evidence / "sway.log").open("w")
    sway = subprocess.Popen(["sway", "--unsupported-gpu", "--config", str(config)], env=env,
                            stdout=sway_log, stderr=subprocess.STDOUT, start_new_session=True)
    children = []

    def stop(process):
        if process and process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=5)
            except (ProcessLookupError, subprocess.TimeoutExpired):
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass

    def swaymsg(*args):
        return subprocess.check_output(["swaymsg", *args], env=env, text=True)

    def windows():
        def walk(node):
            yield node
            for child in node.get("nodes", []) + node.get("floating_nodes", []):
                yield from walk(child)
        tree = json.loads(swaymsg("-t", "get_tree"))
        return [n for n in walk(tree) if n.get("shell") == "xdg_shell"]

    def wait_for(predicate, what, timeout=8):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.1)
        raise TimeoutError(what)

    def run_streaming(command, name, on_line=None, timeout=900):
        """Runs a child, logs its output, and calls on_line for each line."""
        with (evidence / f"{name}.log").open("w") as output:
            child = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     text=True, start_new_session=True, bufsize=1)
            children.append(child)
            deadline = time.monotonic() + timeout
            while True:
                if time.monotonic() > deadline:
                    stop(child)
                    raise TimeoutError(name)
                ready, _, _ = select.select([child.stdout], [], [], 1)
                if ready:
                    line = child.stdout.readline()
                    if not line:
                        break
                    output.write(line)
                    output.flush()
                    if on_line:
                        on_line(line.rstrip("\n"))
                elif child.poll() is not None:
                    break
            return child.wait(timeout=30)

    try:
        wait_for(lambda: any(not p.name.endswith(".lock") for p in runtime.glob("wayland-*"))
                 and list(runtime.glob("sway-ipc.*.sock")), "headless sway", 15)
        env["WAYLAND_DISPLAY"] = next(p.name for p in runtime.glob("wayland-*") if not p.name.endswith(".lock"))
        env["SWAYSOCK"] = str(next(runtime.glob("sway-ipc.*.sock")))
        (evidence / "source.json").write_text(json.dumps({
            "hensou": source, "hostname": "aka", "output": "HEADLESS-1 2400x1600 scale 1.5",
            "renderer": {"compositor": "pixman", "client": "OpenGL RHI on Mesa llvmpipe"},
            "sway": subprocess.check_output(["sway", "--version"], text=True).strip(),
        }, indent=2) + "\n")

        if "suite" in modes:
            code = run_streaming([tests_binary, "tests/files"], "suite")
            results["phases"]["suite"] = code
            log(f"suite exit {code}")

        if "capture" in modes:
            if ack.exists():
                shutil.rmtree(ack)
            ack.mkdir(parents=True)
            shots = evidence / "captures"
            shots.mkdir()

            def on_capture(line):
                marker = "HENSOU_CAPTURE "
                at = line.find(marker)
                if at < 0:
                    return
                name = line[at + len(marker):].strip()
                subprocess.run(["grim", "-o", "HEADLESS-1", str(shots / f"{name}.png")], env=env, check=True)
                (ack / name).write_text("ok\n")
                log(f"captured {name}")

            code = run_streaming([tests_binary, "tests/files/capture"], "capture", on_capture)
            results["phases"]["capture"] = code
            results["captures"] = sorted(p.name for p in shots.glob("*.png"))
            log(f"capture exit {code}, {len(results['captures'])} images")

        if "process" in modes:
            checks = {}
            app_log = (evidence / "process.log").open("w")
            resident = subprocess.Popen([app_binary, "--daemon"], env=env, stdout=app_log,
                                        stderr=subprocess.STDOUT, start_new_session=True)
            children.append(resident)
            wait_for(lambda: (runtime / "hensou" / "files.sock").exists(), "resident socket")
            time.sleep(1.5)
            checks["daemon_opens_no_window"] = not windows()
            started = time.monotonic()
            second = subprocess.run([app_binary, "/home/fixture"], env=env, timeout=20, capture_output=True, text=True)
            checks["second_launch_exit"] = second.returncode
            checks["second_launch_seconds"] = round(time.monotonic() - started, 2)
            wait_for(lambda: any(w.get("name") == "fixture" for w in windows()), "folder window from the handoff")
            third = subprocess.run([app_binary], env=env, timeout=20)
            checks["computer_launch_exit"] = third.returncode
            wait_for(lambda: any(w.get("name") == "Myoko" for w in windows()), "Computer window titled Myoko")
            time.sleep(1)
            subprocess.run(["grim", "-o", "HEADLESS-1", str(evidence / "process-windows.png")], env=env, check=True)
            service = f"org.kde.StatusNotifierItem-{resident.pid}-1"

            def gdbus(*args):
                return subprocess.run(["gdbus", "call", "--session", "--dest", service, *args], env=env,
                                      capture_output=True, text=True, timeout=10)
            sni_id = gdbus("--object-path", "/StatusNotifierItem", "--method", "org.freedesktop.DBus.Properties.Get",
                           "org.kde.StatusNotifierItem", "Id")
            checks["sni_id"] = sni_id.stdout.strip() or sni_id.stderr.strip()
            layout = gdbus("--object-path", "/MenuBar", "--method", "com.canonical.dbusmenu.GetLayout", "0", "-1", "[]")
            checks["sni_menu"] = layout.stdout.strip() or layout.stderr.strip()
            clicked = gdbus("--object-path", "/MenuBar", "--method", "com.canonical.dbusmenu.Event", "1", "clicked", "<0>", "0")
            checks["sni_show_transfers_call"] = clicked.returncode
            wait_for(lambda: any(w.get("name") == "Transfers" for w in windows()), "Transfers window from the tray menu")
            subprocess.run(["grim", "-o", "HEADLESS-1", str(evidence / "process-transfers.png")], env=env, check=True)
            swaymsg("[app_id=.*] kill")
            wait_for(lambda: not windows(), "all windows closed")
            time.sleep(1.5)
            checks["resident_after_windows_close"] = resident.poll() is None
            daemon_again = subprocess.run([app_binary, "--daemon"], env=env, timeout=20)
            checks["daemon_handoff_exit"] = daemon_again.returncode
            time.sleep(0.5)
            checks["daemon_handoff_opens_no_window"] = not windows()
            stop(resident)
            results["phases"]["process"] = checks
            ok = (checks["daemon_opens_no_window"] and checks["second_launch_exit"] == 0 and checks["computer_launch_exit"] == 0
                  and "hensou-files" in checks["sni_id"] and "Show Transfers" in checks["sni_menu"] and "Cancel All" in checks["sni_menu"]
                  and checks["sni_show_transfers_call"] == 0 and checks["resident_after_windows_close"]
                  and checks["daemon_handoff_exit"] == 0 and checks["daemon_handoff_opens_no_window"])
            checks["pass"] = ok
            log("process checks " + json.dumps(checks))
    finally:
        for child in children:
            stop(child)
        stop(sway)
        stop(bus)
        (evidence / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        log(f"EVIDENCE {evidence}")

failed = [name for name, value in results["phases"].items()
          if (isinstance(value, int) and value != 0) or (isinstance(value, dict) and not value.get("pass"))]
if set(results["phases"]) != set(modes) or failed:
    log(f"FAILED {failed or 'incomplete'}")
    sys.exit(1)
log("PASS " + ",".join(modes))
