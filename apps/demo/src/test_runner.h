#ifndef HENSOU_DEMO_TEST_RUNNER_H
#define HENSOU_DEMO_TEST_RUNNER_H
#include <QObject>
#include <QString>
class HensouTestSetup : public QObject {
    Q_OBJECT
public slots:
    void applicationAvailable();
};
int run_tests(const QString &directory);
#endif
