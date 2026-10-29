#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 sway grim
"""Finite fixture orchestration. Run only under the shared Aka heavy queue."""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import select
import subprocess
import sys
import tempfile
import time

assert os.uname().nodename.split(".")[0] == "aka"
packaged = len(sys.argv) > 3 and sys.argv[3] == "--packaged"
source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
evidence = Path("/tmp/hensou-foundation-416d014746da/evidence") / f"demo-{source}"
evidence.mkdir(parents=True, exist_ok=True)
(evidence / "source.json").write_text(json.dumps({"hensou": source, "mountainous_baseline": "a905fd62309a3027a654ce01a504d54540dc7f6a", "hostname": "aka"}, indent=2) + "\n")
with tempfile.TemporaryDirectory(prefix="hensou-demo-") as temporary:
    base = Path(temporary)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    state = base / "state" / "mountainous"
    os.environ.pop("FONTCONFIG_FILE", None)
    env = os.environ | {
        "XDG_RUNTIME_DIR": str(runtime), "XDG_STATE_HOME": str(base / "state"),
        "WLR_BACKENDS": "headless", "WLR_HEADLESS_OUTPUTS": "2", "WLR_LIBINPUT_NO_DEVICES": "1",
        "WLR_RENDERER": "pixman", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
        "QT_WAYLAND_DISABLE_WINDOWDECORATION": "1", "QML_DISABLE_DISK_CACHE": "1",
    }
    if packaged:
        for variable in ("LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH", "QT_PLUGIN_PATH", "QT_QPA_PLATFORM_PLUGIN_PATH", "HENSOU_QML_IMPORT_PATH", "HENSOU_FONT_DIRECTORY"):
            env.pop(variable, None)
    config = base / "sway.conf"
    config.write_text("""output HEADLESS-1 mode 1600x1000 scale 1 position 0 0
output HEADLESS-2 mode 1800x1200 scale 1.5 position 1600 0
seat seat0 fallback true
focus_follows_mouse no
default_border none
default_floating_border none
for_window [app_id=\"hensou-demo-tests\"] floating enable
for_window [title=\"Hensou.*\"] floating enable
""")
    with (evidence / "sway.log").open("w") as sway_log:
        sway = subprocess.Popen(["sway", "--unsupported-gpu", "--config", str(config)], env=env, stdout=sway_log, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
        tests = None
        keyboard = None
        pointer = None
        main = None
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

            keyboard = subprocess.Popen(["wtype", "-s", "120000"], env=env, start_new_session=True, close_fds=True)

            pointer = subprocess.Popen([sys.executable, "tests/demo/pointer.py", "2800", "1000"], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, start_new_session=True, close_fds=True)

            def pointer_reply():
                ready, _, _ = select.select([pointer.stdout], [], [], 5)
                if not ready:
                    raise TimeoutError("virtual pointer reply")
                reply = pointer.stdout.readline().strip()
                if not reply:
                    raise RuntimeError("virtual pointer exited")
                return reply

            assert pointer_reply() == "pointer ready"

            def pointer_command(command):
                pointer.stdin.write(command + "\n")
                pointer.stdin.flush()
                assert pointer_reply() == "ok"

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

            def wait_window(title):
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    matches = [node for node in nodes(tree) if node.get("name") == title and node.get("shell") == "xdg_shell"]
                    if matches:
                        return max(matches, key=lambda node: node["id"])
                    time.sleep(0.05)
                raise TimeoutError(f"Wayland window {title!r} did not map; titles={[node.get('name') for node in nodes(tree)]}")

            def phase(name):
                if name == "prime-input":
                    window = wait_window("Hensou demo")
                    criterion = f'[con_id={window["id"]}]'
                    swaymsg(criterion + " move to output HEADLESS-1")
                    swaymsg(criterion + " move absolute position 0 0")
                    swaymsg(criterion + " focus")
                    subprocess.run(["wtype", "-k", "Shift_L"], env=env, check=True)
                elif name == "open-native-menu":
                    subprocess.run(["wtype", "-k", "Return"], env=env, check=True)
                elif name == "close-native-menu":
                    subprocess.run(["wtype", "-k", "Escape"], env=env, check=True)
                elif name.startswith("block-parent-"):
                    _, _, x, y = name.split("-")
                    pointer_command(f"move {x} {y}")
                    pointer_command("click")
                elif name == "close-native-dialog":
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    focused = [node.get("name") for node in nodes(tree) if node.get("focused")]
                    print("MODAL_COMPOSITOR_FOCUS=" + repr(focused), flush=True)
                    subprocess.run(["wtype", "-k", "Escape"], env=env, check=True)
                elif name == "create":
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
                elif name in ("capture-menu-escape", "capture-modal"):
                    subprocess.run(["grim", "-o", "HEADLESS-1", str(evidence / f"{name}.png")], env=env, check=True)
                elif name == "prepare-capture":
                    window = wait_window("Hensou capture")
                    criterion = f'[con_id={window["id"]}]'
                    swaymsg(criterion + " move to output HEADLESS-2")
                    swaymsg(criterion + " move absolute position 1600 0")
                elif name.startswith("capture-"):
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    window = next(node for node in nodes(tree) if node.get("name") == "Hensou capture")
                    rect = window["rect"]
                    expected = (220, 640) if name.endswith("narrow") else (1000, 180)
                    assert (rect["width"], rect["height"]) == expected, rect
                    assert 1600 <= rect["x"] and rect["x"] + rect["width"] <= 2800, rect
                    assert 0 <= rect["y"] and rect["y"] + rect["height"] <= 800, rect
                    (evidence / f"{name}.json").write_text(json.dumps({"rect": rect, "scale": 1.5, "source": source}, indent=2) + "\n")
                    geometry = f'{rect["x"]},{rect["y"]} {rect["width"]}x{rect["height"]}'
                    subprocess.run(["grim", "-g", geometry, str(evidence / f"{name}.png")], env=env, check=True)

            tests = subprocess.Popen(["timeout", "--kill-after=5", "120", sys.argv[1], str(Path("tests/demo").resolve())], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True, close_fds=True)
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
            main_binary = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(sys.argv[1]).with_name("hensou-demo")
            with (evidence / "main.log").open("w") as main_log:
                main = subprocess.Popen([str(main_binary)], env=env, stdout=main_log, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
                window = wait_window("Hensou demo")
                criterion = f'[con_id={window["id"]}]'
                swaymsg(criterion + " move to output HEADLESS-1")
                swaymsg(criterion + " move absolute position 0 0")
                swaymsg(criterion + " focus")
                subprocess.run(["wtype", "-M", "ctrl", "-k", "a", "-m", "ctrl", "packaged draft"], env=env, check=True)
                pointer_command("move 80 35")
                pointer_command("click")
                write(("platinum", "dark", "on"), atomic=True)
                time.sleep(0.3)  # Finite wait for the real host's theme reload/frame.
                if main.poll() is not None:
                    raise RuntimeError("the actual demo exited during startup/interaction")
                window = wait_window("Hensou demo")
                rect = window["rect"]
                geometry = f'{rect["x"]},{rect["y"]} {rect["width"]}x{rect["height"]}'
                subprocess.run(["grim", "-g", geometry, str(evidence / "main-interactive.png")], env=env, check=True)
                print(f"MAIN_READY executable={main_binary} clean_runtime={packaged} source={source}")
        finally:
            for process in (main, tests, keyboard, pointer, sway):
                if process is None or process.poll() is not None:
                    continue
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
