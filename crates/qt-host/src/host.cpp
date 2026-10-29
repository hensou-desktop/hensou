#include "window_metrics.h"
#include "hensou-qt-host/src/theme.cxxqt.h"
#include <QDir>
#include <QEvent>
#include <QFileSystemWatcher>
#include <QQuickWindow>
#include <QTimer>

WindowMetrics::WindowMetrics(QQuickItem *parent) : QQuickItem(parent) {
    connect(this, &QQuickItem::windowChanged, this, &WindowMetrics::follow);
    follow(window());
}
void WindowMetrics::follow(QQuickWindow *window) {
    if (m_window) m_window->removeEventFilter(this);
    disconnect(m_screenChanged);
    m_window = window;
    if (m_window) {
        m_window->installEventFilter(this);
        m_screenChanged = connect(m_window, &QWindow::screenChanged, this, [this] { refresh(); });
    }
    refresh();
}
void WindowMetrics::refresh() {
    const qreal ratio = m_window ? m_window->devicePixelRatio() : 1.0;
    if (qFuzzyCompare(m_ratio, ratio)) return;
    m_ratio = ratio;
    emit devicePixelRatioChanged();
}
bool WindowMetrics::eventFilter(QObject *object, QEvent *event) {
    if (object == m_window && (event->type() == QEvent::DevicePixelRatioChange || event->type() == QEvent::Show))
        refresh();
    return QQuickItem::eventFilter(object, event);
}

namespace hensou {
bool engine_has_roots(const QQmlApplicationEngine &engine) { return !engine.rootObjects().isEmpty(); }

void watch_theme(HostTheme &theme, const QString &directory) {
    // Parent-owned native watchers have no detached thread or shutdown race.
    // Watch directories as well as files: atomic rename replaces file inodes.
    auto *watcher = new QFileSystemWatcher(&theme);
    auto *debounce = new QTimer(&theme);
    debounce->setInterval(35);
    debounce->setSingleShot(true);
    QObject::connect(debounce, &QTimer::timeout, &theme, [&theme] { theme.reload(); });
    auto repair = [watcher, directory] {
        QStringList wanted;
        QString ancestor = directory;
        while (!QDir(ancestor).exists()) {
            const auto parent = QFileInfo(ancestor).absolutePath();
            if (parent == ancestor) break;
            ancestor = parent;
        }
        wanted << ancestor;
        if (QDir(directory).exists()) {
            wanted << directory;
            for (const auto &name : {"theme-name", "theme", "theme-extra"}) {
                const auto path = directory + '/' + name;
                if (QFileInfo::exists(path)) wanted << path;
            }
        }
        wanted.removeDuplicates();
        const auto current = watcher->directories() + watcher->files();
        for (const auto &path : current) if (!wanted.contains(path)) watcher->removePath(path);
        for (const auto &path : wanted) if (!current.contains(path)) watcher->addPath(path);
    };
    auto changed = [repair, debounce] { repair(); debounce->start(); };
    QObject::connect(watcher, &QFileSystemWatcher::directoryChanged, &theme, changed);
    QObject::connect(watcher, &QFileSystemWatcher::fileChanged, &theme, changed);
    // Recover if a watched directory is deleted then recreated, or addPath
    // failed transiently. No writes or directory creation by a reader.
    auto *recovery = new QTimer(&theme);
    recovery->setInterval(1000);
    QObject::connect(recovery, &QTimer::timeout, &theme, [repair, &theme] { repair(); theme.reload(); });
    repair();
    recovery->start();
}
}
