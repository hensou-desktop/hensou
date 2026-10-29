"""Read the real client's xdg_popup roles, grabs, configures and keyboard targets."""
import re


def summarize(text):
    surfaces = {}
    popups = {}
    grabs = []
    enters = []
    geometry = {}
    done = []
    phase = "startup"
    for line in text.splitlines():
        marker = re.search(r"HENSOU_PHASE ([\w-]+)", line)
        if marker:
            phase = marker[1]
        match = re.search(r"new id xdg_surface[@#](\d+), wl_surface[@#](\d+)", line)
        if match:
            surfaces[int(match[1])] = int(match[2])
        match = re.search(r"xdg_surface[@#](\d+)\.get_popup\(new id xdg_popup[@#](\d+)", line)
        if match:
            popups[int(match[2])] = {"surface": surfaces.get(int(match[1])), "phase": phase}
        match = re.search(r"xdg_popup[@#](\d+)\.grab\(", line)
        if match:
            grabs.append({"popup": int(match[1]), "phase": phase})
        match = re.search(r"wl_keyboard[@#]\d+\.enter\([^,]+, wl_surface[@#](\d+)", line)
        if match:
            enters.append({"surface": int(match[1]), "phase": phase})
        match = re.search(r"xdg_popup[@#](\d+)\.configure\((-?\d+), (-?\d+), (\d+), (\d+)\)", line)
        if match:
            geometry[int(match[1])] = [int(value) for value in match.groups()[1:]]
        match = re.search(r"xdg_popup[@#](\d+)\.popup_done\(", line)
        if match:
            done.append({"popup": int(match[1]), "phase": phase})
    return {"popups": popups, "grabs": grabs, "keyboard_enters": enters, "geometry": geometry, "popup_done": done}
