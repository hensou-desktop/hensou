#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""One fixed-keymap virtual keyboard for the private Wayland test session."""
import array
import ctypes
import hashlib
import json
import re
import os
import socket
import struct
import sys
import time

from pointer import Wire


class RuleNames(ctypes.Structure):
    _fields_ = [(name, ctypes.c_char_p) for name in ("rules", "model", "layout", "variant", "options")]


def keymap_text():
    library = ctypes.CDLL(os.environ["HENSOU_XKBCOMMON_LIBRARY"])
    library.xkb_context_new.argtypes = [ctypes.c_int]
    library.xkb_context_new.restype = ctypes.c_void_p
    library.xkb_context_include_path_append.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    library.xkb_context_include_path_append.restype = ctypes.c_int
    library.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.POINTER(RuleNames), ctypes.c_int]
    library.xkb_keymap_new_from_names.restype = ctypes.c_void_p
    library.xkb_keymap_get_as_string.argtypes = [ctypes.c_void_p, ctypes.c_int]
    library.xkb_keymap_get_as_string.restype = ctypes.c_void_p
    library.xkb_keymap_new_from_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
    library.xkb_keymap_new_from_string.restype = ctypes.c_void_p
    library.xkb_state_new.argtypes = [ctypes.c_void_p]
    library.xkb_state_new.restype = ctypes.c_void_p
    library.xkb_state_key_get_one_sym.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    library.xkb_state_key_get_one_sym.restype = ctypes.c_uint32
    library.xkb_state_unref.argtypes = [ctypes.c_void_p]
    library.xkb_keysym_get_name.argtypes = [ctypes.c_uint32, ctypes.c_char_p, ctypes.c_size_t]
    library.xkb_keysym_get_name.restype = ctypes.c_int
    library.xkb_keymap_unref.argtypes = [ctypes.c_void_p]
    library.xkb_context_unref.argtypes = [ctypes.c_void_p]
    context = library.xkb_context_new(1)  # XKB_CONTEXT_NO_DEFAULT_INCLUDES
    if not context:
        raise RuntimeError("xkb context")
    keymap = None
    text = None
    try:
        if library.xkb_context_include_path_append(context, os.fsencode(os.environ["XKB_CONFIG_ROOT"])) != 1:
            raise RuntimeError("pinned xkb include path")
        names = RuleNames(b"evdev", b"pc105", b"us", None, None)
        keymap = library.xkb_keymap_new_from_names(context, ctypes.byref(names), 0)
        if not keymap:
            raise RuntimeError("us keymap")
        text = library.xkb_keymap_get_as_string(keymap, 1)
        if not text:
            raise RuntimeError("keymap serialization")
        original = ctypes.string_at(text).decode()
        replaced, count = re.subn(r"key\s+<FK13>\s*\{[^}]*\}", "key <FK13> { [ F13 ] }", original, count=1)
        if count != 1:
            raise RuntimeError("No FK13 in the pinned full US keymap")
        final = library.xkb_keymap_new_from_string(context, replaced.encode(), 1, 0)
        if not final:
            raise RuntimeError("F13 override did not compile")
        try:
            state = library.xkb_state_new(final)
            if not state:
                raise RuntimeError("F13 state")
            try:
                symbol = library.xkb_state_key_get_one_sym(state, 183 + 8)
                name = ctypes.create_string_buffer(64)
                library.xkb_keysym_get_name(symbol, name, len(name))
                info = {"physical_code": 183, "xkb_code": 191, "keysym": symbol, "keysym_name": name.value.decode()}
                if name.value != b"F13":
                    raise RuntimeError(f"Not an actual F13 key: {info}")
                return replaced.encode() + b"\0", info
            finally:
                library.xkb_state_unref(state)
        finally:
            library.xkb_keymap_unref(final)
    finally:
        if text:
            libc = ctypes.CDLL(None)
            libc.free.argtypes = [ctypes.c_void_p]
            libc.free(text)
        if keymap:
            library.xkb_keymap_unref(keymap)
        library.xkb_context_unref(context)


def main():
    wire = Wire()
    registry = wire.new_id()
    wire.send(1, 1, struct.pack("<I", registry))
    globals_ = {}

    def event(obj, opcode, body):
        if obj == registry and opcode == 0:
            name, length = struct.unpack_from("<II", body)
            interface = body[8:8 + length - 1].decode()
            globals_[interface] = name

    wire.roundtrip(event)

    def bind(interface):
        obj = wire.new_id()
        wire.send(registry, 0, struct.pack("<I", globals_[interface]) + wire.string(interface) + struct.pack("<II", 1, obj))
        return obj

    seat = bind("wl_seat")
    manager = bind("zwp_virtual_keyboard_manager_v1")
    keyboard = wire.new_id()
    wire.send(manager, 0, struct.pack("<II", seat, keyboard))
    text, info = keymap_text()
    fd = os.memfd_create("hensou-keymap", os.MFD_CLOEXEC)
    try:
        with os.fdopen(fd, "wb", closefd=False) as file:
            file.write(text)
        payload = struct.pack("<II", 1, len(text))
        packet = struct.pack("<II", keyboard, (16 << 16)) + payload
        sent = wire.sock.sendmsg([packet], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", [fd]))])
        if sent != len(packet):
            raise RuntimeError("partial Wayland keymap request")
    finally:
        os.close(fd)
    wire.send(keyboard, 2, struct.pack("<IIII", 0, 0, 0, 0))
    wire.roundtrip(lambda *args: None)
    codes = {"Return": 28, "Escape": 1, "F13": 183, "Shift_L": 42}
    letters = dict(zip("qwertyuiop", range(16, 26))) | dict(zip("asdfghjkl", range(30, 39))) | dict(zip("zxcvbnm", range(44, 51))) | {" ": 57}

    def tap(code):
        wire.send(keyboard, 1, struct.pack("<III", int(time.monotonic() * 1000) & 0xFFFFFFFF, code, 1))
        wire.roundtrip(lambda *args: None)
        time.sleep(0.05)
        wire.send(keyboard, 1, struct.pack("<III", int(time.monotonic() * 1000) & 0xFFFFFFFF, code, 0))
        wire.roundtrip(lambda *args: None)

    print("keyboard ready " + json.dumps(info | {"sha256": hashlib.sha256(text).hexdigest()}), flush=True)
    for line in sys.stdin:
        command, _, value = line.rstrip("\n").partition(" ")
        if command == "key":
            tap(codes[value])
        elif command == "select-all":
            wire.send(keyboard, 2, struct.pack("<IIII", 4, 0, 0, 0))
            tap(letters["a"])
            wire.send(keyboard, 2, struct.pack("<IIII", 0, 0, 0, 0))
            wire.roundtrip(lambda *args: None)
        elif command == "text":
            for letter in value:
                tap(letters[letter])
        else:
            raise ValueError("unknown keyboard fixture command")
        print("ok", flush=True)


if __name__ == "__main__":
    main()
