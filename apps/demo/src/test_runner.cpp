#include "test_runner.h"
#include <QtQuickTest/quicktest.h>
int run_tests(const QString &directory) {
    int argc = 1;
    char name[] = "hensou-demo-tests";
    char *argv[] = {name, nullptr};
    return quick_test_main(argc, argv, "hensou-demo", directory.toUtf8().constData());
}
