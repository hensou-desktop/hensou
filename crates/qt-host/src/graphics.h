#ifndef HENSOU_GRAPHICS_CONFIGURATION_H
#define HENSOU_GRAPHICS_CONFIGURATION_H
namespace hensou {
// Call once before creating the first QQuickWindow, in every host entrypoint.
void configure_graphics();
}
#endif
