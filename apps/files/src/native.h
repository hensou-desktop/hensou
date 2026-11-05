#ifndef HENSOU_FILES_NATIVE_H
#define HENSOU_FILES_NATIVE_H
#include <QHash>
#include <QMimeData>
#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Data offered to other apps by a drag or the clipboard. Local files are
// ready at once. Remote files are prepared (downloaded) by the service: the
// offer is made at drag start or at Copy, and the paths are handed over when
// the target reads them, after the download (files.md). A cancelled download
// hands over nothing.
class FilesMimeData : public QMimeData {
    Q_OBJECT
public:
    FilesMimeData(const QList<QUrl> &urls, const QByteArray &locations, bool cut, qint64 pending);
    ~FilesMimeData() override;
    QStringList formats() const override;
    bool hasFormat(const QString &mimeType) const override;
    void resolve(const QList<QUrl> &urls);
    void abandon();
    qint64 pending() const { return m_pending; }
    QByteArray locations() const { return m_locations; }
    bool cut() const { return m_cut; }
signals:
    void settled();
protected:
    QVariant retrieveData(const QString &mimeType, QMetaType type) const override;
private:
    bool waitForPaths() const;
    QList<QUrl> m_urls;
    QByteArray m_locations;
    bool m_cut = false;
    qint64 m_pending = 0;
    bool m_ready = true;
    bool m_abandoned = false;
};

// Native services QML cannot reach: keyboard modifiers at a drop, native
// drags with file data, the file clipboard, residency.
class FilesNative : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString locationsMime READ locationsMime CONSTANT FINAL)
    Q_PROPERTY(QString dragButton READ dragButton NOTIFY dragButtonChanged FINAL)
public:
    explicit FilesNative(QObject *parent = nullptr) : QObject(parent) {}
    static QString locationsMime() { return QStringLiteral("application/x-hensou-locations"); }
    QString dragButton() const { return m_dragButton; }

    // Qt::KeyboardModifiers as an int, read from the platform now.
    Q_INVOKABLE int keyboardModifiers() const;
    // Starts a native drag and blocks until it ends. Returns "copy", "move"
    // or "ignore". button is "left" or "right" (Memphis right-drag menu).
    // pending > 0 marks remote files whose paths arrive through resolve().
    Q_INVOKABLE QString startDrag(QQuickItem *source, const QStringList &urls, const QString &locations,
                                  qint64 pending, const QString &button, int count);
    // Puts files on the clipboard (text/uri-list and the GNOME cut marker).
    Q_INVOKABLE void setClipboard(const QStringList &urls, const QString &locations, bool cut, qint64 pending);
    // {locations: JSON or "", urls: [...], cut: bool}
    Q_INVOKABLE QVariantMap clipboard() const;
    Q_INVOKABLE void clearClipboard();
    // A Prepare finished: hand its paths to the waiting drag or clipboard.
    Q_INVOKABLE void resolve(qint64 request, const QStringList &paths);
    // A Prepare was cancelled or failed: hand over nothing.
    Q_INVOKABLE void abandon(qint64 request);
    Q_INVOKABLE QString fileUrl(const QString &path) const;
signals:
    void dragButtonChanged();
private:
    QString m_dragButton;
};

namespace hensou_files {
// Files stays resident after its windows close: transfers outlive them.
void keep_resident();
}

#endif
