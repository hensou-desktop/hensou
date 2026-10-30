#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 sway grim
"""Finite fixture orchestration. Run only under the shared Aka heavy queue."""

import json
import os
import re
import select
import shlex
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from protocol_trace import summarize

assert os.uname().nodename.split(".")[0] == "aka"
packaged = len(sys.argv) > 3 and sys.argv[3] == "--packaged"
modes = os.environ.get("HENSOU_TEST_MODES", "grab-probe,modal,suite").split(",")
assert modes and set(modes) <= {"grab-probe", "modal", "suite"}
mode_suffix = "" if modes == ["grab-probe", "modal", "suite"] else "-" + "-".join(modes)
source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
evidence = (
    Path("/tmp/hensou-foundation-416d014746da/evidence")
    / f"demo-{source}{'-packaged' if packaged else ''}{mode_suffix}"
)
evidence.mkdir(parents=True, exist_ok=True)
observer = evidence / "server-grab-observer.so"
flags = subprocess.check_output(["pkg-config", "--cflags", "--libs", "wlroots-0.20"], text=True)
subprocess.run(["cc", "-shared", "-fPIC", "-O2", "-Wall", "-Wextra", "-Werror", "tests/demo/grab_observer.c", "-o", str(observer), *shlex.split(flags), "-ldl"], check=True)
(evidence / "source.json").write_text(
    json.dumps(
        {
            "hensou": source,
            "mountainous_baseline": "a905fd62309a3027a654ce01a504d54540dc7f6a",
            "hostname": "aka",
            "modes": modes,
            "sway_version": subprocess.check_output(
                ["sway", "--version"], text=True
            ).strip(),
            "declared_renderer": {
                "compositor": "pixman",
                "client": "OpenGL RHI",
                "software": "Mesa llvmpipe",
                "egl_vendor": os.environ.get("__EGL_VENDOR_LIBRARY_DIRS"),
                "dri_path": os.environ.get("LIBGL_DRIVERS_PATH"),
            },
        },
        indent=2,
    )
    + "\n"
)
with tempfile.TemporaryDirectory(prefix="hensou-demo-") as temporary:
    base = Path(temporary)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    state = base / "state" / "mountainous"
    os.environ.pop("FONTCONFIG_FILE", None)
    env = os.environ | {
        "XDG_RUNTIME_DIR": str(runtime),
        "XDG_STATE_HOME": str(base / "state"),
        "WLR_BACKENDS": "headless",
        "WLR_HEADLESS_OUTPUTS": "2",
        "WLR_LIBINPUT_NO_DEVICES": "1",
        "WLR_RENDERER": "pixman",
        "WLR_RENDERER_ALLOW_SOFTWARE": "1",
        "LP_NUM_THREADS": "2",
        "QT_QPA_PLATFORM": "wayland",
        "LIBGL_ALWAYS_SOFTWARE": "1",
        "QSG_RHI_BACKEND": "opengl",
        "QSG_INFO": "1",
        "QT_LOGGING_RULES": "qt.gui.popup.debug=true;qt.quick.controls.popup.window.debug=true;qt.gui.focus.debug=true;qt.qpa.wayland.input.debug=true;qt.qpa.wayland.window.debug=true",
        "QT_WAYLAND_DISABLE_WINDOWDECORATION": "1",
        "QML_DISABLE_DISK_CACHE": "1",
    }
    env.pop("QT_QUICK_BACKEND", None)
    if packaged:
        for variable in (
            "LD_LIBRARY_PATH",
            "QML_IMPORT_PATH",
            "QML2_IMPORT_PATH",
            "QT_PLUGIN_PATH",
            "QT_QPA_PLATFORM_PLUGIN_PATH",
            "HENSOU_QML_IMPORT_PATH",
            "HENSOU_FONT_DIRECTORY",
        ):
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
        sway = subprocess.Popen(
            ["sway", "--debug", "--unsupported-gpu", "--config", str(config)],
            env=env | {"LD_PRELOAD": str(observer)},
            stdout=sway_log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            close_fds=True,
        )
        tests = None
        keyboard = None
        pointer = None
        main = None
        foreign = None
        foreign_log = None
        probe_state = {"baseline": 0}
        input_state = {"pending": None, "focus": None}
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
                    raise RuntimeError(
                        f"headless sway exited before readiness: returncode={sway.returncode}; log={evidence / 'sway.log'}"
                    )
                time.sleep(0.05)
            else:
                raise TimeoutError("headless sway readiness")

            pointer = subprocess.Popen(
                [sys.executable, "tests/demo/pointer.py", "2800", "1000"],
                env=env,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                text=True,
                start_new_session=True,
                close_fds=True,
            )

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

            keyboard = subprocess.Popen(
                [sys.executable, "tests/demo/keyboard.py"],
                env=env,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                text=True,
                start_new_session=True,
                close_fds=True,
            )

            def keyboard_reply():
                ready, _, _ = select.select([keyboard.stdout], [], [], 5)
                if not ready:
                    raise TimeoutError("virtual keyboard reply")
                reply = keyboard.stdout.readline().strip()
                if not reply:
                    raise RuntimeError("virtual keyboard exited")
                return reply

            ready = keyboard_reply()
            assert ready.startswith("keyboard ready "), ready
            (evidence / "keyboard.json").write_text(
                json.dumps(
                    json.loads(ready.removeprefix("keyboard ready "))
                    | {
                        "xkb_library": env["HENSOU_XKBCOMMON_LIBRARY"],
                        "xkb_root": env["XKB_CONFIG_ROOT"],
                    },
                    indent=2,
                )
                + "\n"
            )

            def keyboard_command(command):
                keyboard.stdin.write(command + "\n")
                keyboard.stdin.flush()
                assert keyboard_reply() == "ok"

            def send_key(key):
                keyboard_command("key " + key)

            def swaymsg(*args):
                return subprocess.check_output(["swaymsg", *args], env=env, text=True)

            def write(values, atomic=False):
                state.mkdir(parents=True, exist_ok=True)
                for filename, value in zip(
                    ["theme-name", "theme", "theme-extra"], values
                ):
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

            def wait_window(title, size=None, position=None, settled=False):
                stable = 0
                previous = None
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    matches = [
                        node
                        for node in nodes(tree)
                        if node.get("name") == title
                        and node.get("shell") == "xdg_shell"
                    ]
                    if matches:
                        window = max(matches, key=lambda node: node["id"])
                        if (
                            size is None
                            or (window["rect"]["width"], window["rect"]["height"])
                            == size
                        ) and (
                            position is None
                            or (window["rect"]["x"], window["rect"]["y"]) == position
                        ):
                            stable = stable + 1 if window["rect"] == previous else 1
                            previous = window["rect"]
                            if not settled or stable >= 3:
                                return window
                        else:
                            stable = 0
                    time.sleep(0.05)
                raise TimeoutError(
                    f"Wayland window {title!r} did not settle: size={size} position={position}; matches={[(node.get('id'), node.get('name'), node.get('rect'), node.get('pid')) for node in nodes(tree) if node.get('name') == title]}"
                )

            def foreign_count():
                values = re.findall(
                    r"FOREIGN_F13 (\d+)", (evidence / "foreign-probe.trace").read_text()
                )
                return max(map(int, values), default=0)

            def foreign_enters():
                return len(re.findall(r"wl_pointer[@#]\d+\.enter\(", (evidence / "foreign-probe.trace").read_text()))

            def move_to_foreign():
                window = wait_window("Hensou foreign probe")
                rect = window["rect"]
                pointer_command(f"move {rect['x'] + rect['width'] // 2} {rect['y'] + rect['height'] // 2}")
                return window

            def phase(name, trace_path):
                if name == "prime-input":
                    window = wait_window("Hensou demo")
                    criterion = f"[con_id={window['id']}]"
                    swaymsg(criterion + " move to output HEADLESS-1")
                    swaymsg(criterion + " move absolute position 0 0")
                    swaymsg(criterion + " focus")
                    send_key("Shift_L")
                elif name == "fixture-state":
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    snapshot = [
                        {
                            key: node.get(key)
                            for key in (
                                "id",
                                "name",
                                "pid",
                                "app_id",
                                "focused",
                                "rect",
                            )
                        }
                        for node in nodes(tree)
                        if node.get("shell") == "xdg_shell"
                    ]
                    (evidence / "fixture-state.json").write_text(
                        json.dumps(snapshot, indent=2) + "\n"
                    )
                    print("FIXTURE_COMPOSITOR_STATE=" + repr(snapshot), flush=True)
                elif name == "probe-foreign-positive":
                    window = wait_window("Hensou foreign probe")
                    trace = evidence / "foreign-probe.trace"
                    start = len(trace.read_text())
                    swaymsg(f"[con_id={window['id']}] focus")
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        if "FOREIGN_READY true true" in trace.read_text()[start:]:
                            break
                        time.sleep(0.02)
                    else:
                        raise TimeoutError("Foreign native activation/receiver focus acknowledgement")
                    before_enters = foreign_enters()
                    move_to_foreign()
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline and foreign_enters() <= before_enters:
                        time.sleep(0.02)
                    assert foreign_enters() > before_enters, "No closed-popup foreign pointer entry"
                    probe_state["enters"] = foreign_enters()
                    before = foreign_count()
                    send_key("F13")
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline and foreign_count() != before + 1:
                        time.sleep(0.02)
                    assert foreign_count() == before + 1, (
                        "Foreign client did not receive the positive F13"
                    )
                    probe_state["baseline"] = before + 1
                    print(
                        f"FOREIGN_POSITIVE_F13={foreign_count()} rect={window['rect']}",
                        flush=True,
                    )
                elif name == "probe-focus-owner":
                    window = wait_window("Hensou demo")
                    rect = window["rect"]
                    pointer_command(f"move {rect['x'] + rect['width'] // 2} {rect['y'] + rect['height'] // 2}")
                    swaymsg(f"[con_id={window['id']}] focus")
                elif name == "probe-foreign-pointer":
                    move_to_foreign()
                    time.sleep(0.1)
                    assert foreign_enters() == probe_state["enters"], "Native pointer grab leaked foreign entry"
                    print(f"FOREIGN_POINTER_WITHHELD={foreign_enters()}", flush=True)
                elif name == "probe-foreign-key":
                    window = wait_window("Hensou foreign probe")
                    send_key("F13")
                    time.sleep(0.15)
                    assert foreign_count() == probe_state["baseline"], (
                        "Native grab leaked F13 to foreign client"
                    )
                    print(
                        f"FOREIGN_BLOCKED_F13={foreign_count()} attempted_con_id={window['id']}",
                        flush=True,
                    )
                elif name == "probe-after-close":
                    owner = wait_window("Hensou demo")["rect"]
                    pointer_command(f"move {owner['x'] + owner['width'] // 2} {owner['y'] + owner['height'] // 2}")
                    before = foreign_enters()
                    move_to_foreign()
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline and foreign_enters() <= before:
                        time.sleep(0.02)
                    assert foreign_enters() > before, "Closing native popup did not restore foreign pointer entry"
                    send_key("F13")
                    print(f"FOREIGN_POINTER_RESTORED={foreign_enters()}", flush=True)
                elif name in ("resize-small-parent", "resize-large-parent"):
                    window = wait_window("Hensou demo")
                    width, height = (
                        (220, 180) if name == "resize-small-parent" else (640, 480)
                    )
                    swaymsg(
                        f"[con_id={window['id']}] resize set width {width} px height {height} px"
                    )
                    wait_window("Hensou demo", size=(width, height), settled=True)
                    # Sway preserves a floating window's centre while resizing.
                    # Place it only after its new native size has settled.
                    swaymsg(f"[con_id={window['id']}] move absolute position 0 0")
                    placed = wait_window(
                        "Hensou demo",
                        size=(width, height),
                        position=(0, 0),
                        settled=True,
                    )
                    (evidence / f"geometry-{name}.json").write_text(
                        json.dumps(
                            {
                                "before": window["rect"],
                                "requested_size": [width, height],
                                "requested_position": [0, 0],
                                "settled": placed["rect"],
                            },
                            indent=2,
                        )
                        + "\n"
                    )
                elif name in ("open-native-menu", "open-native-dialog"):
                    send_key("Return")
                elif name == "close-native-menu":
                    send_key("Escape")
                elif name.startswith(("block-parent-", "parent-click-")):
                    x, y = map(int, name.split("-")[-2:])
                    window = wait_window("Hensou demo", size=(640, 480))
                    rect = window["rect"]
                    x += rect["x"]
                    y += rect["y"]
                    outputs = [
                        output["rect"]
                        for output in json.loads(swaymsg("-t", "get_outputs"))
                        if output.get("active")
                    ]
                    assert (
                        rect["x"] <= x < rect["x"] + rect["width"]
                        and rect["y"] <= y < rect["y"] + rect["height"]
                    ), (rect, x, y)
                    assert any(
                        output["x"] <= rect["x"]
                        and output["y"] <= rect["y"]
                        and rect["x"] + rect["width"] <= output["x"] + output["width"]
                        and rect["y"] + rect["height"] <= output["y"] + output["height"]
                        for output in outputs
                    ), (rect, outputs)
                    assert any(
                        output["x"] <= x < output["x"] + output["width"]
                        and output["y"] <= y < output["y"] + output["height"]
                        for output in outputs
                    ), (x, y, outputs)
                    (evidence / f"geometry-{name}.json").write_text(
                        json.dumps(
                            {"owner": rect, "target": [x, y], "outputs": outputs},
                            indent=2,
                        )
                        + "\n"
                    )
                    print(
                        f"REAL_PARENT_CLICK phase={name} layout={x},{y} native_rect={rect}",
                        flush=True,
                    )
                    owner_surface = summarize(trace_path.read_text())[
                        "last_parent_surface"
                    ]
                    assert owner_surface is not None, "No actual owner surface"
                    input_state["pending"] = {
                        "surface": owner_surface,
                        "x": x - rect["x"],
                        "y": y - rect["y"],
                        "phase": name,
                    }
                    # Force a fresh real enter/motion, including when the target
                    # is unchanged from the positive-control click.
                    pointer_command(
                        f"move {rect['x'] + rect['width'] - 12} {rect['y'] + rect['height'] - 12}"
                    )
                    pointer_command(f"move {x} {y}")
                elif name == "close-native-dialog":
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    focused = [
                        node.get("name") for node in nodes(tree) if node.get("focused")
                    ]
                    print("MODAL_COMPOSITOR_FOCUS=" + repr(focused), flush=True)
                    send_key("Escape")
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
                    swaymsg(
                        '[title="Hensou scale fractional"] move to output HEADLESS-2'
                    )
                elif name == "rescale":
                    swaymsg("output HEADLESS-2 scale 2")
                elif name == "restore-scale":
                    swaymsg("output HEADLESS-2 scale 1.5")
                elif name in ("capture-menu-escape", "capture-modal"):
                    subprocess.run(
                        ["grim", "-o", "HEADLESS-1", str(evidence / f"{name}.png")],
                        env=env,
                        check=True,
                    )
                elif name.startswith("prepare-capture-"):
                    window = wait_window("Hensou capture")
                    criterion = f"[con_id={window['id']}]"
                    width, height = (
                        (220, 640) if name.endswith("narrow") else (1000, 180)
                    )
                    swaymsg(
                        criterion + f" resize set width {width} px height {height} px"
                    )
                    resized = wait_window("Hensou capture", size=(width, height), settled=True)
                    swaymsg(criterion + " move to output HEADLESS-2")
                    swaymsg(criterion + " move absolute position 1600 0")
                    placed = wait_window("Hensou capture", size=(width, height), position=(1600, 0), settled=True)
                    (evidence / f"geometry-{name}.json").write_text(json.dumps({"resized": resized["rect"], "requested_position": [1600, 0], "settled": placed["rect"]}, indent=2) + "\n")
                elif name.startswith("capture-"):
                    tree = json.loads(swaymsg("-t", "get_tree"))
                    window = next(
                        node
                        for node in nodes(tree)
                        if node.get("name") == "Hensou capture"
                    )
                    rect = window["rect"]
                    expected = (220, 640) if name.endswith("narrow") else (1000, 180)
                    assert (rect["width"], rect["height"]) == expected, rect
                    assert 1600 <= rect["x"] and rect["x"] + rect["width"] <= 2800, rect
                    assert 0 <= rect["y"] and rect["y"] + rect["height"] <= 800, rect
                    (evidence / f"{name}.json").write_text(
                        json.dumps(
                            {"rect": rect, "scale": 1.5, "source": source}, indent=2
                        )
                        + "\n"
                    )
                    geometry = (
                        f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
                    )
                    subprocess.run(
                        ["grim", "-g", geometry, str(evidence / f"{name}.png")],
                        env=env,
                        check=True,
                    )
                    pixels = struct.unpack(
                        ">II", (evidence / f"{name}.png").read_bytes()[16:24]
                    )
                    assert pixels == (
                        round(rect["width"] * 1.5),
                        round(rect["height"] * 1.5),
                    ), pixels

            for mode in modes:
                traced = mode != "suite"
                if mode == "grab-probe":
                    foreign_log = (evidence / "foreign-probe.trace").open("w")
                    foreign = subprocess.Popen(
                        [sys.argv[1], str(Path("tests/foreign-probe").resolve())],
                        env=env | {"WAYLAND_DEBUG": "client"},
                        stdout=foreign_log,
                        stderr=subprocess.STDOUT,
                        start_new_session=True,
                        close_fds=True,
                    )
                    wait_window("Hensou foreign probe")
                test_env = env | {"WAYLAND_DEBUG": "client"}
                input_state["pending"] = None
                input_state["focus"] = None
                arguments = [
                    "timeout",
                    "--kill-after=5",
                    "120",
                    sys.argv[1],
                    str(
                        Path(
                            "tests/grab-probe" if mode == "grab-probe" else "tests/demo"
                        ).resolve()
                    ),
                ]
                if traced:
                    arguments.append(
                        "NativeGrab::test_cross_client"
                        if mode == "grab-probe"
                        else "StandaloneDemo::test_native_popup_and_modal_focus_return"
                    )
                tests = subprocess.Popen(
                    arguments,
                    env=test_env,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    start_new_session=True,
                    close_fds=True,
                )
                filename = f"wayland-{mode}.trace" if traced else "tests.log"
                phase_error = None
                with (evidence / filename).open("w") as log:
                    for line in tests.stdout:
                        if not line.lstrip().startswith("["):
                            print(line, end="", flush=True)
                        log.write(line)
                        log.flush()
                        position = None
                        enter = re.search(
                            r"wl_pointer[@#]\d+\.enter\(\d+, wl_surface[@#](\d+), ([^,]+), ([^)]+)\)",
                            line,
                        )
                        leave = re.search(r"wl_pointer[@#]\d+\.leave\(", line)
                        motion = re.search(
                            r"wl_pointer[@#]\d+\.motion\([^,]+, ([^,]+), ([^)]+)\)",
                            line,
                        )
                        if enter:
                            input_state["focus"] = int(enter[1])
                            position = (float(enter[2]), float(enter[3]))
                        elif leave:
                            input_state["focus"] = None
                        elif motion:
                            position = (float(motion[1]), float(motion[2]))
                        pending = input_state["pending"]
                        if (
                            pending
                            and position
                            and input_state["focus"] == pending["surface"]
                            and abs(position[0] - pending["x"]) < 1
                            and abs(position[1] - pending["y"]) < 1
                        ):
                            print(f"OWNER_POINTER_READY={pending}", flush=True)
                            input_state["pending"] = None
                            pointer_command("click")
                        match = re.search(r"HENSOU_PHASE ([\w-]+)", line)
                        if match and (
                            phase_error is None or match[1] == "fixture-state"
                        ):
                            if traced and match[1].startswith("block-parent-"):
                                summary = summarize((evidence / filename).read_text())
                                modal = [
                                    key
                                    for key, value in summary["popups"].items()
                                    if value["phase"] == "open-native-dialog"
                                ]
                                if modal:
                                    bounds = summary["geometry"].get(modal[-1])
                                    if bounds:
                                        px, py = map(int, match[1].split("-")[-2:])
                                        dx, dy, dw, dh = bounds
                                        assert not (
                                            dx <= px < dx + dw and dy <= py < dy + dh
                                        ), bounds
                                        print(
                                            f"NATIVE_POPUP_UNCOVERED rect={bounds} target={px},{py}",
                                            flush=True,
                                        )
                            try:
                                phase(match[1], evidence / filename)
                            except Exception as error:
                                phase_error = error
                                print(
                                    f"FIXTURE_PHASE_ERROR={error!r}; draining the native client trace",
                                    flush=True,
                                )
                code = tests.wait(timeout=120)
                if traced:
                    summary = summarize((evidence / filename).read_text())
                    (evidence / f"wayland-{mode}.json").write_text(
                        json.dumps(summary, indent=2) + "\n"
                    )
                if phase_error is not None:
                    raise phase_error
                assert input_state["pending"] is None, (
                    "No actual owner pointer focus/motion before click"
                )
                if code:
                    raise SystemExit(code)
                if traced:
                    role_phase = (
                        "open-native-menu"
                        if mode == "grab-probe"
                        else "open-native-dialog"
                    )
                    popups = [
                        key
                        for key, value in summary["popups"].items()
                        if value["phase"] == role_phase
                    ]
                    assert popups, "No actual native popup role"
                    popup = popups[-1]
                    assert any(item["popup"] == popup for item in summary["grabs"]), (
                        "No native grab request"
                    )
                    # wlroots 0.20.2 installs a client grab but leaves current seat
                    # focus unchanged. Its keyboard enter callback is a no-op.
                    assert any(
                        item["surface"] == summary["popups"][popup]["parent_surface"]
                        for item in summary["keyboard_enters"]
                    ), "No actual retained-owner keyboard target"
                    assert summary["buffers"], "No actual Mesa wl_shm buffers recorded"
                    assert all(
                        buffer["stride"] % 4 == 0
                        and buffer["stride"] >= buffer["width"] * 4
                        for buffer in summary["buffers"]
                    ), "Native host did not negotiate safe 32-bit buffers"
                    renderer = [
                        line
                        for line in (evidence / filename).read_text().splitlines()
                        if "OpenGL VENDOR:" in line
                    ]
                    assert any("RENDERER: llvmpipe" in line for line in renderer), (
                        "Not actual OpenGL llvmpipe rendering"
                    )
                    (evidence / f"renderer-{mode}.json").write_text(
                        json.dumps(renderer, indent=2) + "\n"
                    )
                    print(
                        f"NATIVE_POPUP_ROLE_GRAB_RETAINED_TARGET_32BIT={mode}:PASS",
                        flush=True,
                    )
                if mode == "grab-probe":
                    records = re.findall(r"HENSOU_SERVER_KEY time=(\d+) key=183 state=1 nondefault=(\d) grab=(\S+) default=(\S+) surface=(\d+) client=(\S+) keyboard=(\S+)", (evidence / "sway.log").read_text())
                    assert [int(record[1]) for record in records] == [0, 1, 0], ("No actual default/grabbed/default native F13 dispatch", records)
                    (evidence / "server-keyboard-grab.json").write_text(json.dumps(records, indent=2) + "\n")
                    print("SERVER_ACTUAL_KEYBOARD_GRAB_DEFAULT_ACTIVE_DEFAULT=PASS", flush=True)
                    foreign.terminate()
                    foreign.wait(timeout=5)
                    foreign_log.close()
                    foreign = None
                    foreign_log = None
            print(f"DEMO_EVIDENCE={evidence}")
            main_binary = (
                Path(sys.argv[2])
                if len(sys.argv) > 2
                else Path(sys.argv[1]).with_name("hensou-demo")
            )
            with (evidence / "main.log").open("w") as main_log:
                main = subprocess.Popen(
                    [str(main_binary)],
                    env=env,
                    stdout=main_log,
                    stderr=subprocess.STDOUT,
                    start_new_session=True,
                    close_fds=True,
                )
                window = wait_window("Hensou demo")
                criterion = f"[con_id={window['id']}]"
                swaymsg(criterion + " move to output HEADLESS-1")
                swaymsg(criterion + " move absolute position 0 0")
                swaymsg(criterion + " focus")
                keyboard_command("select-all")
                keyboard_command("text packaged draft")
                pointer_command("move 80 35")
                pointer_command("click")
                write(("platinum", "dark", "on"), atomic=True)
                time.sleep(0.3)  # Finite wait for the real host's theme reload/frame.
                if main.poll() is not None:
                    raise RuntimeError(
                        "the actual demo exited during startup/interaction"
                    )
                window = wait_window("Hensou demo")
                rect = window["rect"]
                geometry = f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
                subprocess.run(
                    ["grim", "-g", geometry, str(evidence / "main-interactive.png")],
                    env=env,
                    check=True,
                )
                print(
                    f"MAIN_READY executable={main_binary} clean_runtime={packaged} source={source}"
                )
        finally:
            for process in (main, tests, foreign, keyboard, pointer, sway):
                if process is None or process.poll() is not None:
                    continue
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
