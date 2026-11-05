#include "native.h"
#include <QClipboard>
#include <QDrag>
#include <QEventLoop>
#include <QFont>
#include <QGuiApplication>
#include <QPainter>
#include <QPixmap>
#include <QQuickWindow>

namespace {
// Offers that wait for a Prepare, by request id.
QHash<qint64, QList<QPointer<FilesMimeData>>> &waiting() {
    static QHash<qint64, QList<QPointer<FilesMimeData>>> offers;
    return offers;
}
const QString uriList = QStringLiteral("text/uri-list");
const QString gnomeCopied = QStringLiteral("x-special/gnome-copied-files");
const QString plainText = QStringLiteral("text/plain");
const QString utf8Text = QStringLiteral("text/plain;charset=utf-8");
}

FilesMimeData::FilesMimeData(const QList<QUrl> &urls, const QByteArray &locations, bool cut, qint64 pending)
    : m_urls(urls), m_locations(locations), m_cut(cut), m_pending(pending), m_ready(pending <= 0) {
    if (m_pending > 0) waiting()[m_pending].append(this);
}

FilesMimeData::~FilesMimeData() {
    if (m_pending > 0) {
        auto it = waiting().find(m_pending);
        if (it != waiting().end()) {
            it->removeAll(this);
            it->removeAll(nullptr);
            if (it->isEmpty()) waiting().erase(it);
        }
    }
}

QStringList FilesMimeData::formats() const {
    QStringList out;
    if (!m_locations.isEmpty()) out << FilesNative::locationsMime();
    out << uriList << gnomeCopied << utf8Text << plainText;
    return out;
}

bool FilesMimeData::hasFormat(const QString &mimeType) const { return formats().contains(mimeType); }

void FilesMimeData::resolve(const QList<QUrl> &urls) {
    m_urls = urls;
    m_ready = true;
    emit settled();
}

void FilesMimeData::abandon() {
    m_abandoned = true;
    m_ready = true;
    emit settled();
}

bool FilesMimeData::waitForPaths() const {
    if (!m_ready) {
        // The download shows in the transfers window meanwhile; Cancel there
        // abandons this offer. The loop keeps the UI responsive.
        QEventLoop loop;
        QObject::connect(this, &FilesMimeData::settled, &loop, &QEventLoop::quit);
        while (!m_ready) loop.exec();
    }
    return !m_abandoned;
}

QVariant FilesMimeData::retrieveData(const QString &mimeType, QMetaType type) const {
    Q_UNUSED(type);
    if (mimeType == FilesNative::locationsMime()) return m_locations;
    if (!waitForPaths()) return QByteArray();
    QByteArray list;
    for (const QUrl &url : m_urls) list += url.toEncoded() + "\r\n";
    if (mimeType == uriList) return list;
    if (mimeType == gnomeCopied) {
        QByteArray marked = m_cut ? "cut" : "copy";
        for (const QUrl &url : m_urls) marked += "\n" + url.toEncoded();
        return marked;
    }
    if (mimeType == plainText || mimeType == utf8Text) {
        QStringList paths;
        for (const QUrl &url : m_urls) paths << (url.isLocalFile() ? url.toLocalFile() : url.toString());
        return paths.join('\n').toUtf8();
    }
    return QVariant();
}

int FilesNative::keyboardModifiers() const { return int(QGuiApplication::queryKeyboardModifiers().toInt()); }

namespace {
QList<QUrl> toUrls(const QStringList &urls) {
    QList<QUrl> out;
    for (const QString &url : urls) out << QUrl(url);
    return out;
}

// A small count badge under the pointer; there are no thumbnails.
QPixmap badge(int count, qreal ratio) {
    const QString text = QString::number(count);
    QFont font = QGuiApplication::font();
    font.setPixelSize(12);
    const int width = qMax(20, QFontMetrics(font).horizontalAdvance(text) + 10);
    QPixmap pixmap(QSize(width, 20) * ratio);
    pixmap.setDevicePixelRatio(ratio);
    pixmap.fill(Qt::transparent);
    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setBrush(QColor(0x33, 0x33, 0x99));
    painter.setPen(Qt::black);
    painter.drawRoundedRect(QRectF(0.5, 0.5, width - 1, 19), 9, 9);
    painter.setPen(Qt::white);
    painter.setFont(font);
    painter.drawText(QRectF(0, 0, width, 20), Qt::AlignCenter, text);
    return pixmap;
}
}

QString FilesNative::startDrag(QQuickItem *source, const QStringList &urls, const QString &locations,
                               qint64 pending, const QString &button, int count) {
    if (!source) return QStringLiteral("ignore");
    auto *drag = new QDrag(source);
    drag->setMimeData(new FilesMimeData(toUrls(urls), locations.toUtf8(), false, pending));
    const qreal ratio = source->window() ? source->window()->devicePixelRatio() : 1.0;
    drag->setPixmap(badge(qMax(1, count), ratio));
    drag->setHotSpot(QPoint(-8, -8));
    m_dragButton = button;
    emit dragButtonChanged();
    // The target chooses copy or move by each theme's rule; other apps get
    // copy unless they ask for move.
    const Qt::DropAction result = drag->exec(Qt::CopyAction | Qt::MoveAction, Qt::CopyAction);
    drag->deleteLater();
    m_dragButton.clear();
    emit dragButtonChanged();
    if (result == Qt::MoveAction) return QStringLiteral("move");
    if (result == Qt::CopyAction) return QStringLiteral("copy");
    return QStringLiteral("ignore");
}

void FilesNative::setClipboard(const QStringList &urls, const QString &locations, bool cut, qint64 pending) {
    QGuiApplication::clipboard()->setMimeData(new FilesMimeData(toUrls(urls), locations.toUtf8(), cut, pending));
}

QVariantMap FilesNative::clipboard() const {
    QVariantMap out;
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (!data) return out;
    // Our own offer answers from memory; never wait on our own download here.
    if (auto *own = qobject_cast<const FilesMimeData *>(data)) {
        out.insert(QStringLiteral("locations"), QString::fromUtf8(own->locations()));
        out.insert(QStringLiteral("cut"), own->cut());
        return out;
    }
    QStringList urls;
    for (const QUrl &url : data->urls()) urls << url.toString();
    out.insert(QStringLiteral("urls"), urls);
    out.insert(QStringLiteral("locations"), QString::fromUtf8(data->data(FilesNative::locationsMime())));
    out.insert(QStringLiteral("cut"), data->data(gnomeCopied).startsWith("cut"));
    return out;
}

void FilesNative::clearClipboard() { QGuiApplication::clipboard()->clear(); }

void FilesNative::resolve(qint64 request, const QStringList &paths) {
    QList<QUrl> urls;
    for (const QString &path : paths) urls << QUrl::fromLocalFile(path);
    const auto offers = waiting().take(request);
    for (const auto &offer : offers)
        if (offer) offer->resolve(urls);
}

void FilesNative::abandon(qint64 request) {
    const auto offers = waiting().take(request);
    for (const auto &offer : offers)
        if (offer) offer->abandon();
}

QString FilesNative::fileUrl(const QString &path) const { return QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded); }

namespace hensou_files {
void keep_resident() { QGuiApplication::setQuitOnLastWindowClosed(false); }
}
