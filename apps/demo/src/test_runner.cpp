#include "test_runner.h"
#include "hensou-qt-host/src/fonts.h"
#include "hensou-qt-host/src/graphics.h"
#include <QtQuickTest/quicktest.h>
void HensouTestSetup::applicationAvailable() {
    hensou::configure_graphics();
    if (!hensou::register_fonts(qEnvironmentVariable("HENSOU_FONT_DIRECTORY")))
        qFatal("Cannot register packaged fonts for the demo test");
}
int run_tests(const QString &directory, const QString &function) {
    int argc = function.isEmpty() ? 1 : 2;
    auto encodedFunction = function.toUtf8();
    char name[] = "hensou-demo-tests";
    char *argv[] = {name, encodedFunction.data(), nullptr};
    HensouTestSetup setup;
    return quick_test_main_with_setup(argc, argv, "hensou-demo", directory.toUtf8().constData(), &setup);
}
