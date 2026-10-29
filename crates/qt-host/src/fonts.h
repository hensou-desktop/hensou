#ifndef HENSOU_FONT_REGISTRATION_H
#define HENSOU_FONT_REGISTRATION_H
#include <QString>
namespace hensou {
// Call on the GUI thread after QGuiApplication exists and before QML loads.
bool register_fonts(const QString &directory);
}
#endif
