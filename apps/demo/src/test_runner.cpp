#include "test_runner.h"
#include "hensou-qt-host/src/fonts.h"
#include <QtQuickTest/quicktest.h>
void HensouTestSetup::applicationAvailable() {
    if (!hensou::register_fonts(qEnvironmentVariable("HENSOU_FONT_DIRECTORY")))
        qFatal("Cannot register packaged fonts for the demo test");
}
int run_tests(const QString &directory) {
    int argc = 1;
    char name[] = "hensou-demo-tests";
    char *argv[] = {name, nullptr};
    HensouTestSetup setup;
    return quick_test_main_with_setup(argc, argv, "hensou-demo", directory.toUtf8().constData(), &setup);
}
