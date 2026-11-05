#include "test_runner.h"
#include "hensou-qt-host/src/fonts.h"
#include "hensou-qt-host/src/graphics.h"
#include "native.h"
#include <QtQuickTest/quicktest.h>
void FilesTestSetup::applicationAvailable() {
    hensou::configure_graphics();
    hensou_files::keep_resident();
    if (!hensou::register_fonts(qEnvironmentVariable("HENSOU_FONT_DIRECTORY")))
        qFatal("Cannot register packaged fonts for the Files tests");
}
int run_tests(const QString &directory, const QString &function) {
    int argc = function.isEmpty() ? 1 : 2;
    auto encodedFunction = function.toUtf8();
    char name[] = "hensou-files-tests";
    char *argv[] = {name, encodedFunction.data(), nullptr};
    FilesTestSetup setup;
    return quick_test_main_with_setup(argc, argv, "hensou-files", directory.toUtf8().constData(), &setup);
}
