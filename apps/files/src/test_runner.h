#ifndef HENSOU_FILES_TEST_RUNNER_H
#define HENSOU_FILES_TEST_RUNNER_H
#include <QObject>
#include <QString>
class FilesTestSetup : public QObject {
    Q_OBJECT
public slots:
    void applicationAvailable();
};
int run_tests(const QString &directory, const QString &function);
#endif
