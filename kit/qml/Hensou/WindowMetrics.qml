pragma Singleton
import QtQuick

QtObject {
    // Shell adapters can carry the same provider properties directly. Reading
    // the ancestor chain in a binding tracks both reparenting and scale changes.
    function ratio(item) {
        for (let p = item; p; p = p.parent) {
            if (p.hensouDevicePixelRatio !== undefined && p.hensouDevicePixelRatio > 0)
                return p.hensouDevicePixelRatio;
        }
        // Existing shell's out-of-window fallback. Hosts must supply a provider.
        return 1.5;
    }
    function iconSource(item, name) {
        for (let p = item; p; p = p.parent) {
            if (p.hensouIconResolver) return p.hensouIconResolver(name);
        }
        return "";
    }
}
