#ifndef HENSOU_FILES_TRAY_H
#define HENSOU_FILES_TRAY_H
#include <QDBusAbstractAdaptor>
#include <QDBusArgument>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// org.kde.StatusNotifierItem and com.canonical.dbusmenu wire types.
struct SniPixmap {
    int width = 0;
    int height = 0;
    QByteArray data;
};
using SniPixmaps = QList<SniPixmap>;
struct SniToolTip {
    QString icon;
    SniPixmaps image;
    QString title;
    QString text;
};
struct MenuLayout {
    int id = 0;
    QVariantMap properties;
    QList<MenuLayout> children;
};
struct MenuItemProperties {
    int id = 0;
    QVariantMap properties;
};
using MenuItemPropertiesList = QList<MenuItemProperties>;
struct MenuItemKeys {
    int id = 0;
    QStringList names;
};
using MenuItemKeysList = QList<MenuItemKeys>;
struct MenuEvent {
    int id = 0;
    QString eventId;
    QDBusVariant data;
    uint timestamp = 0;
};
using MenuEventList = QList<MenuEvent>;

Q_DECLARE_METATYPE(SniPixmap)
Q_DECLARE_METATYPE(SniToolTip)
Q_DECLARE_METATYPE(MenuLayout)
Q_DECLARE_METATYPE(MenuItemProperties)
Q_DECLARE_METATYPE(MenuItemKeys)
Q_DECLARE_METATYPE(MenuEvent)

QDBusArgument &operator<<(QDBusArgument &argument, const SniPixmap &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, SniPixmap &value);
QDBusArgument &operator<<(QDBusArgument &argument, const SniToolTip &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, SniToolTip &value);
QDBusArgument &operator<<(QDBusArgument &argument, const MenuLayout &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuLayout &value);
QDBusArgument &operator<<(QDBusArgument &argument, const MenuItemProperties &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuItemProperties &value);
QDBusArgument &operator<<(QDBusArgument &argument, const MenuItemKeys &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuItemKeys &value);
QDBusArgument &operator<<(QDBusArgument &argument, const MenuEvent &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuEvent &value);

class TransferTray;

class SniAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierItem")
    Q_PROPERTY(QString Category READ category)
    Q_PROPERTY(QString Id READ id)
    Q_PROPERTY(QString Title READ title)
    Q_PROPERTY(QString Status READ status)
    Q_PROPERTY(int WindowId READ windowId)
    Q_PROPERTY(QString IconName READ iconName)
    Q_PROPERTY(SniPixmaps IconPixmap READ iconPixmap)
    Q_PROPERTY(QString OverlayIconName READ emptyName)
    Q_PROPERTY(SniPixmaps OverlayIconPixmap READ iconPixmap)
    Q_PROPERTY(QString AttentionIconName READ emptyName)
    Q_PROPERTY(SniPixmaps AttentionIconPixmap READ iconPixmap)
    Q_PROPERTY(QString AttentionMovieName READ emptyName)
    Q_PROPERTY(QString IconThemePath READ emptyName)
    Q_PROPERTY(SniToolTip ToolTip READ toolTip)
    Q_PROPERTY(bool ItemIsMenu READ itemIsMenu)
    Q_PROPERTY(QDBusObjectPath Menu READ menu)
public:
    explicit SniAdaptor(QObject *object, TransferTray *tray);
    QString category() const { return QStringLiteral("ApplicationStatus"); }
    QString id() const { return QStringLiteral("hensou-files"); }
    QString title() const;
    QString status() const;
    int windowId() const { return 0; }
    QString iconName() const { return QStringLiteral("hensou-files"); }
    SniPixmaps iconPixmap() const { return {}; }
    QString emptyName() const { return QString(); }
    SniToolTip toolTip() const;
    bool itemIsMenu() const { return false; }
    QDBusObjectPath menu() const { return QDBusObjectPath(QStringLiteral("/MenuBar")); }
public slots:
    void Activate(int x, int y);
    void SecondaryActivate(int x, int y);
    void ContextMenu(int x, int y);
    void Scroll(int delta, const QString &orientation);
signals:
    void NewTitle();
    void NewIcon();
    void NewAttentionIcon();
    void NewOverlayIcon();
    void NewToolTip();
    void NewStatus(const QString &status);
private:
    TransferTray *m_tray;
};

class MenuAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.canonical.dbusmenu")
    Q_PROPERTY(uint Version READ version)
    Q_PROPERTY(QString TextDirection READ textDirection)
    Q_PROPERTY(QString Status READ menuStatus)
    Q_PROPERTY(QStringList IconThemePath READ iconThemePath)
public:
    explicit MenuAdaptor(QObject *object, TransferTray *tray);
    uint version() const { return 3; }
    QString textDirection() const { return QStringLiteral("ltr"); }
    QString menuStatus() const { return QStringLiteral("normal"); }
    QStringList iconThemePath() const { return {}; }
    void changed();
public slots:
    uint GetLayout(int parentId, int recursionDepth, const QStringList &propertyNames, MenuLayout &layout);
    MenuItemPropertiesList GetGroupProperties(const QList<int> &ids, const QStringList &propertyNames);
    QDBusVariant GetProperty(int id, const QString &name);
    void Event(int id, const QString &eventId, const QDBusVariant &data, uint timestamp);
    QList<int> EventGroup(const MenuEventList &events);
    bool AboutToShow(int id);
    QList<int> AboutToShowGroup(const QList<int> &ids, QList<int> &idErrors);
signals:
    void ItemsPropertiesUpdated(const MenuItemPropertiesList &updatedProps, const MenuItemKeysList &removedProps);
    void LayoutUpdated(uint revision, int parent);
    void ItemActivationRequested(int id, uint timestamp);
private:
    QVariantMap itemProperties(int id) const;
    TransferTray *m_tray;
    uint m_revision = 1;
};

// The Files transfer indicator: a StatusNotifierItem that exists only while
// transfers run (set active). Its menu offers Show Transfers and Cancel All.
// Without a session bus it does nothing and reports registered: false.
class TransferTray : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged FINAL)
    Q_PROPERTY(bool needsAttention READ needsAttention WRITE setNeedsAttention NOTIFY needsAttentionChanged FINAL)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged FINAL)
    Q_PROPERTY(QString toolTip READ toolTip WRITE setToolTip NOTIFY toolTipChanged FINAL)
    Q_PROPERTY(QString showLabel READ showLabel WRITE setShowLabel NOTIFY menuChanged FINAL)
    Q_PROPERTY(QString cancelLabel READ cancelLabel WRITE setCancelLabel NOTIFY menuChanged FINAL)
    Q_PROPERTY(bool registered READ registered NOTIFY registeredChanged FINAL)
    Q_PROPERTY(QString serviceName READ serviceName CONSTANT FINAL)
public:
    explicit TransferTray(QObject *parent = nullptr);
    ~TransferTray() override;
    bool active() const { return m_active; }
    void setActive(bool active);
    bool needsAttention() const { return m_attention; }
    void setNeedsAttention(bool attention);
    QString title() const { return m_title; }
    void setTitle(const QString &title);
    QString toolTip() const { return m_toolTip; }
    void setToolTip(const QString &toolTip);
    QString showLabel() const { return m_showLabel; }
    void setShowLabel(const QString &label);
    QString cancelLabel() const { return m_cancelLabel; }
    void setCancelLabel(const QString &label);
    bool registered() const { return m_registered; }
    QString serviceName() const { return m_serviceName; }
    void activateItem(int id);
signals:
    void activeChanged();
    void needsAttentionChanged();
    void titleChanged();
    void toolTipChanged();
    void menuChanged();
    void registeredChanged();
    void showTransfersRequested();
    void cancelAllRequested();
private:
    void publish();
    void withdraw();
    void announce();
    bool m_active = false;
    bool m_attention = false;
    bool m_registered = false;
    QString m_title = QStringLiteral("Files");
    QString m_toolTip;
    QString m_showLabel = QStringLiteral("Show Transfers");
    QString m_cancelLabel = QStringLiteral("Cancel All");
    QString m_serviceName;
    QObject *m_item = nullptr;
    QObject *m_menu = nullptr;
    QPointer<SniAdaptor> m_sni;
    QPointer<MenuAdaptor> m_menuAdaptor;
};

#endif
