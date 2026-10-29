#ifndef HENSOU_MODAL_INPUT_GUARD_H
#define HENSOU_MODAL_INPUT_GUARD_H
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>

// Qt 6.11 may forward unaccepted native-popup input back to its owner.
// Guard that one window, not individual controls or the popup's own window.
class ModalInputGuard : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickWindow *ownerWindow READ ownerWindow WRITE setOwnerWindow NOTIFY ownerWindowChanged FINAL)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged FINAL)
public:
    explicit ModalInputGuard(QObject *parent = nullptr) : QObject(parent) {}
    ~ModalInputGuard() override;
    QQuickWindow *ownerWindow() const { return m_owner; }
    void setOwnerWindow(QQuickWindow *owner);
    bool active() const { return m_active; }
    void setActive(bool active);
signals:
    void ownerWindowChanged();
    void activeChanged();
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    QPointer<QQuickWindow> m_owner;
    QMetaObject::Connection m_destroyed;
    bool m_active = false;
};
#endif
