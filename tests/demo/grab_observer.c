// Test-only, passive observer. Preload into the private Sway process, never Qt.
#define _GNU_SOURCE
#define WLR_USE_UNSTABLE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <wlr/types/wlr_compositor.h>
#include <wlr/types/wlr_seat.h>

void wlr_seat_keyboard_notify_key(struct wlr_seat *seat, uint32_t time_msec,
        uint32_t key, uint32_t state) {
    typedef void (*notify_fn)(struct wlr_seat *, uint32_t, uint32_t, uint32_t);
    static notify_fn original;
    if (!original) {
        original = (notify_fn)dlsym(RTLD_NEXT, "wlr_seat_keyboard_notify_key");
        if (!original) {
            fputs("HENSOU_SERVER_OBSERVER_ERROR: native symbol missing\n", stderr);
            abort();
        }
    }
    struct wlr_surface *surface = seat->keyboard_state.focused_surface;
    fprintf(stderr,
        "HENSOU_SERVER_KEY time=%u key=%u state=%u nondefault=%d grab=%p default=%p surface=%u client=%p keyboard=%p\n",
        time_msec, key, state,
        seat->keyboard_state.grab != seat->keyboard_state.default_grab,
        (void *)seat->keyboard_state.grab, (void *)seat->keyboard_state.default_grab,
        surface ? wl_resource_get_id(surface->resource) : 0,
        surface ? (void *)wl_resource_get_client(surface->resource) : NULL,
        (void *)seat->keyboard_state.keyboard);
    original(seat, time_msec, key, state);
    fprintf(stderr, "HENSOU_SERVER_KEY_DONE time=%u key=%u state=%u\n",
        time_msec, key, state);
}
