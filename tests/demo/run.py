#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 sway grim
"""Finite fixture orchestration. Run only under the shared Aka heavy queue."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

assert os.uname().nodename.split(".")[0] == "aka"
source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
evidence = Path("/tmp/hensou-foundation-416d014746da/evidence") / f"demo-{source}"
evidence.mkdir(parents=True, exist_ok=True)
(evidence / "source.json").write_text(json.dumps({"hensou": source, "mountainous_baseline": "a905fd62309a3027a654ce01a504d54540dc7f6a", "hostname": "aka"}, indent=2) + "\n")
with tempfile.TemporaryDirectory(prefix="hensou-demo-") as temporary:
    base = Path(temporary)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    state = base / "state" / "mountainous"
    env = os.environ | {
        "XDG_RUNTIME_DIR": str(runtime), "XDG_STATE_HOME": str(base / "state"),
        "WLR_BACKENDS": "headless", "WLR_HEADLESS_OUTPUTS": "2", "WLR_LIBINPUT_NO_DEVICES": "1",
        "WLR_RENDERER": "pixman", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
        "QT_WAYLAND_DISABLE_WINDOWDECORATION": "1", "QML_DISABLE_DISK_CACHE": "1",
        "FONTCONFIG_FILE": "/tmp/hensou-foundation-416d014746da/tools/fonts.conf",
    }
    config = base / "sway.conf"
    config.write_text("""output HEADLESS-1 mode 1600x1000 scale 1 position 0 0
output HEADLESS-2 mode 1800x1200 scale 1.5 position 1600 0
seat seat0 fallback true
focus_follows_mouse no
for_window [app_id=\"hensou-demo-tests\"] floating enable
for_window [title=\"Hensou.*\"] floating enable
""")
    with (evidence / "sway.log").open("w") as sway_log:
        sway = subprocess.Popen(["sway", "--unsupported-gpu", "--config", str(config)], env=env, stdout=sway_log, stderr=subprocess.STDOUT)
        tests = None
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                sockets = list(runtime.glob("wayland-*"))
                sockets = [path for path in sockets if not path.name.endswith(".lock")]
                ipc = list(runtime.glob("sway-ipc.*.sock"))
                if sockets and ipc:
                    env["WAYLAND_DISPLAY"] = sockets[0].name
                    env["SWAYSOCK"] = str(ipc[0])
                    break
                if sway.poll() is not None:
                    raise RuntimeError("headless sway exited before readiness")
                time.sleep(0.05)
            else:
                raise TimeoutError("headless sway readiness")

            def swaymsg(*args):
                return subprocess.check_output(["swaymsg", *args], env=env, text=True)

            def write(values, atomic=False):
                state.mkdir(parents=True, exist_ok=True)
                for filename, value in zip(["theme-name", "theme", "theme-extra"], values):
                    destination = state / filename
                    if atomic:
                        temporary = state / (filename + ".new")
                        temporary.write_text(value + "\n")
                        temporary.replace(destination)
                    else:
                        destination.write_text(value + "\n")

            def nodes(node):
                yield node
                for child in node.get("nodes", []) + node.get("floating_nodes", []):
                    yield from nodes(child)

            def phase(name):
                if name == "create":
                    write(("win98", "light", "on"))
                elif name == "invalid":
                    write(("unknown", "lig", "bad"))
                elif name == "missing":
                    for filename in ["theme-name", "theme", "theme-extra"]:
                        (state / filename).unlink(missing_ok=True)
                elif name == "atomic":
                    write(("platinum", "dark", "on"), atomic=True)
                elif name == "recreate":
                    shutil.rmtree(state)
                    write(("win98", "light", "off"), atomic=True)
                elif name == "scales":
                    swaymsg('[title="Hensou scale one"] move to output HEADLESS-1')
                    swaymsg('[title="Hensou scale fractional"] move to output HEADLESS-2')
                elif name == "rescale":
                    swaymsg("output HEADLESS-2 scale 2")
                elif name == "restore-scale":
                    swaymsg("output HEADLESS-2 scale 1.5")
                elif name.startswith("capture-"):
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    window = next(node for node in nodes(tree) if node.get("name") == "Hensou capture")
                    rect = window["rect"]
                    geometry = f'{rect["x"]},{rect["y"]} {rect["width"]}x{rect["height"]}'
                    subprocess.run(["grim", "-g", geometry, str(evidence / f"{name}.png")], env=env, check=True)

            tests = subprocess.Popen([sys.argv[1], str(Path("tests/demo").resolve())], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            with (evidence / "tests.log").open("w") as log:
                for line in tests.stdout:
                    print(line, end="", flush=True)
                    log.write(line)
                    match = re.search(r"HENSOU_PHASE ([\w-]+)", line)
                    if match:
                        phase(match[1])
            code = tests.wait(timeout=120)
            print(f"DEMO_EVIDENCE={evidence}")
            if code:
                raise SystemExit(code)
        finally:
            if tests is not None and tests.poll() is None:
                tests.terminate()
                tests.wait(timeout=10)
            sway.terminate()
            sway.wait(timeout=10)
