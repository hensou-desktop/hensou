import QtQuick
import Hensou.Files
import "Model.js" as Model

// The one owner of Files' view state, built from service events by the pure
// reducer in Model.js. Windows read it; they never keep a second copy of
// listings, transfers or connections.
QtObject {
    id: root
    property var state: Model.emptyState()
    // Request id -> function(event) for events that answer one request.
    property var waiting: ({})
    // Transfers this app started (for showing progress and conflicts).
    property var started: ({})
    // Hosts whose changed key the user has already been told about.
    property var refusedShown: ({})

    signal hostKeyRequested(var prompt)
    signal hostRefused(string host, string fingerprint)
    signal transferUpdated(var transfer)
    signal failed(var request, var error)
    signal prepared(var request, var paths)
    signal eventReceived(var event)

    readonly property var transfers: state.transfers
    readonly property var copies: state.copies
    readonly property var tray: Model.trayState(state.transfers)

    function connect() { FilesBridge.subscribe(); }

    // Sends a files-model command. onAnswer receives events for this request.
    function send(command, onAnswer) {
        const id = FilesBridge.send(JSON.stringify(command));
        if (id === 0) {
            console.warn("Files: the service refused a command", command.command);
            return 0;
        }
        if (onAnswer) {
            const next = Object.assign({}, waiting);
            next[String(id)] = onAnswer;
            waiting = next;
        }
        return id;
    }
    function list(location) {
        state = Model.markLoading(state, location);
        const id = send({ command: "list", location: location });
        if (id) state = Model.noteRequest(state, id, { kind: "list", key: Model.key(location) });
        return id;
    }
    function listing(location) {
        return state.listings[Model.key(location)] || null;
    }
    function connection(location) {
        const host = Model.hostName(location);
        return host ? state.connections[host] || null : null;
    }
    function transfer(sources, destination, mode) {
        const id = send({ command: "transfer", mode: mode, sources: sources, destination: destination });
        if (id) {
            const next = Object.assign({}, started);
            next[String(id)] = true;
            started = next;
        }
        return id;
    }
    function cancelTransfer(id) { return send({ command: "cancel-transfer", id: Number(id) }); }
    function cancelAll() {
        for (const id in state.transfers)
            if (Model.transferActive(state.transfers[id])) cancelTransfer(id);
    }
    function activeTransfers() {
        const out = [];
        for (const id in state.transfers) if (Model.transferActive(state.transfers[id])) out.push(state.transfers[id]);
        return out;
    }

    function finish(id) {
        if (!waiting[String(id)]) return;
        const next = Object.assign({}, waiting);
        delete next[String(id)];
        waiting = next;
    }
    function answer(id, event) {
        const handler = waiting[String(id)];
        if (!handler) return false;
        finish(id);
        handler(event);
        return true;
    }

    function receive(json) {
        let event;
        try { event = JSON.parse(json); } catch (e) { console.warn("Files: unreadable event", e); return; }
        state = Model.reduce(state, event);
        switch (event.event) {
        case "host-key":
            hostKeyRequested(event.prompt);
            break;
        case "connection":
            if (event.state.state === "host-key-changed") {
                const key = event.host + " " + event.state.fingerprint;
                if (!refusedShown[key]) {
                    const shown = Object.assign({}, refusedShown);
                    shown[key] = true;
                    refusedShown = shown;
                    hostRefused(event.host, event.state.fingerprint);
                }
            }
            break;
        case "transfer":
            transferUpdated(event.transfer);
            // A cancelled or failed download hands nothing to its drop.
            if (["cancelled", "failed"].indexOf(event.transfer.state.state) >= 0) FilesNative.abandon(event.transfer.id);
            break;
        case "prepared":
            FilesNative.resolve(event.request, event.paths);
            prepared(event.request, event.paths);
            answer(event.request, event);
            break;
        case "error":
            if (event.request === null || event.request === undefined || !answer(event.request, event))
                failed(event.request, event.error);
            if (event.request !== null && event.request !== undefined) FilesNative.abandon(event.request);
            break;
        case "listing":
        case "info":
        case "handlers":
        case "delete-check":
        case "view":
        case "done":
            if (event.request !== undefined) answer(event.request, event);
            break;
        }
        eventReceived(event);
    }

    property Connections bridge: Connections {
        target: FilesBridge
        function onReceived(json) { root.receive(json); }
    }
}
