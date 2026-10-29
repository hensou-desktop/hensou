#ifndef HENSOU_NATIVE_WINDOW_METRICS_H
#define HENSOU_NATIVE_WINDOW_METRICS_H
#include <QQuickItem>
#include <QPointer>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QtQml/qqmlregistration.h>

class HostTheme;

// QScreen's DPR rounds fractional Wayland scale. QWindow's DPR is the value
// Qt actually uses for this surface. A QQuickItem follows reparenting too.
class WindowMetrics : public QQuickItem {
    Q_OBJECT
    QML_NAMED_ELEMENT(NativeWindowMetrics)
    Q_PROPERTY(qreal devicePixelRatio READ devicePixelRatio NOTIFY devicePixelRatioChanged FINAL)
public:
    explicit WindowMetrics(QQuickItem *parent = nullptr);
    qreal devicePixelRatio() const { return m_ratio; }
signals:
    void devicePixelRatioChanged();
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    void follow(QQuickWindow *window);
    void refresh();
    QPointer<QQuickWindow> m_window;
    qreal m_ratio = 1.0;
    QMetaObject::Connection m_screenChanged;
};

namespace hensou {
void watch_theme(HostTheme &theme, const QString &directory);
bool engine_has_roots(const QQmlApplicationEngine &engine);
bool register_fonts(const QString &directory);
}

#endif
