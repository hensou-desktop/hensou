#include "modal_input_guard.h"
#include <QEvent>

ModalInputGuard::~ModalInputGuard() {
    if (m_owner) m_owner->removeEventFilter(this);
}
void ModalInputGuard::setOwnerWindow(QQuickWindow *owner) {
    if (m_owner == owner) return;
    if (m_owner) m_owner->removeEventFilter(this);
    disconnect(m_destroyed);
    m_owner = owner;
    if (owner) {
        owner->installEventFilter(this);
        m_destroyed = connect(owner, &QObject::destroyed, this, [this] {
            m_owner = nullptr;
            emit ownerWindowChanged();
        });
    }
    emit ownerWindowChanged();
}
void ModalInputGuard::setActive(bool active) {
    if (m_active == active) return;
    m_active = active;
    emit activeChanged();
}
bool ModalInputGuard::eventFilter(QObject *object, QEvent *event) {
    if (!m_active || object != m_owner) return QObject::eventFilter(object, event);
    switch (event->type()) {
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
    case QEvent::MouseButtonDblClick:
    case QEvent::MouseMove:
    case QEvent::Wheel:
    case QEvent::TabletPress:
    case QEvent::TabletMove:
    case QEvent::TabletRelease:
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::TouchCancel:
    case QEvent::KeyPress:
    case QEvent::KeyRelease:
    case QEvent::ShortcutOverride:
    case QEvent::InputMethod:
    case QEvent::ContextMenu:
    case QEvent::NativeGesture:
    case QEvent::DragEnter:
    case QEvent::DragMove:
    case QEvent::Drop:
        event->accept();
        return true;
    default:
        // Expose, resize, focus, DPR and destruction still reach native Qt.
        return QObject::eventFilter(object, event);
    }
}
