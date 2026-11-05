#include "tray.h"
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusServiceWatcher>

// ---- wire types --------------------------------------------------------

QDBusArgument &operator<<(QDBusArgument &argument, const SniPixmap &value) {
    argument.beginStructure();
    argument << value.width << value.height << value.data;
    argument.endStructure();
    return argument;
}
const QDBusArgument &operator>>(const QDBusArgument &argument, SniPixmap &value) {
    argument.beginStructure();
    argument >> value.width >> value.height >> value.data;
    argument.endStructure();
    return argument;
}
QDBusArgument &operator<<(QDBusArgument &argument, const SniToolTip &value) {
    argument.beginStructure();
    argument << value.icon << value.image << value.title << value.text;
    argument.endStructure();
    return argument;
}
const QDBusArgument &operator>>(const QDBusArgument &argument, SniToolTip &value) {
    argument.beginStructure();
    argument >> value.icon >> value.image >> value.title >> value.text;
    argument.endStructure();
    return argument;
}
// (ia{sv}av): children are variants that each hold a layout.
QDBusArgument &operator<<(QDBusArgument &argument, const MenuLayout &value) {
    argument.beginStructure();
    argument << value.id << value.properties;
    argument.beginArray(QMetaType::fromType<QDBusVariant>());
    for (const MenuLayout &child : value.children)
        argument << QDBusVariant(QVariant::fromValue(child));
    argument.endArray();
    argument.endStructure();
    return argument;
}
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuLayout &value) {
    argument.beginStructure();
    argument >> value.id >> value.properties;
    argument.beginArray();
    value.children.clear();
    while (!argument.atEnd()) {
        QDBusVariant child;
        argument >> child;
        value.children << qdbus_cast<MenuLayout>(child.variant());
    }
    argument.endArray();
    argument.endStructure();
    return argument;
}
QDBusArgument &operator<<(QDBusArgument &argument, const MenuItemProperties &value) {
    argument.beginStructure();
    argument << value.id << value.properties;
    argument.endStructure();
    return argument;
}
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuItemProperties &value) {
    argument.beginStructure();
    argument >> value.id >> value.properties;
    argument.endStructure();
    return argument;
}
QDBusArgument &operator<<(QDBusArgument &argument, const MenuItemKeys &value) {
    argument.beginStructure();
    argument << value.id << value.names;
    argument.endStructure();
    return argument;
}
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuItemKeys &value) {
    argument.beginStructure();
    argument >> value.id >> value.names;
    argument.endStructure();
    return argument;
}
QDBusArgument &operator<<(QDBusArgument &argument, const MenuEvent &value) {
    argument.beginStructure();
    argument << value.id << value.eventId << value.data << value.timestamp;
    argument.endStructure();
    return argument;
}
const QDBusArgument &operator>>(const QDBusArgument &argument, MenuEvent &value) {
    argument.beginStructure();
    argument >> value.id >> value.eventId >> value.data >> value.timestamp;
    argument.endStructure();
    return argument;
}

namespace {
void registerTypes() {
    static bool done = false;
    if (done) return;
    done = true;
    qDBusRegisterMetaType<SniPixmap>();
    qDBusRegisterMetaType<SniPixmaps>();
    qDBusRegisterMetaType<SniToolTip>();
    qDBusRegisterMetaType<MenuLayout>();
    qDBusRegisterMetaType<MenuItemProperties>();
    qDBusRegisterMetaType<MenuItemPropertiesList>();
    qDBusRegisterMetaType<MenuItemKeys>();
    qDBusRegisterMetaType<MenuItemKeysList>();
    qDBusRegisterMetaType<MenuEvent>();
    qDBusRegisterMetaType<MenuEventList>();
    qDBusRegisterMetaType<QList<int>>();
}
const QString watcherService = QStringLiteral("org.kde.StatusNotifierWatcher");
constexpr int showItem = 1;
constexpr int cancelItem = 2;
}

// ---- org.kde.StatusNotifierItem ----------------------------------------

SniAdaptor::SniAdaptor(QObject *object, TransferTray *tray) : QDBusAbstractAdaptor(object), m_tray(tray) {
    setAutoRelaySignals(false);
}
QString SniAdaptor::title() const { return m_tray->title(); }
QString SniAdaptor::status() const {
    return m_tray->needsAttention() ? QStringLiteral("NeedsAttention") : QStringLiteral("Active");
}
SniToolTip SniAdaptor::toolTip() const { return SniToolTip{QString(), {}, m_tray->title(), m_tray->toolTip()}; }
void SniAdaptor::Activate(int, int) { m_tray->activateItem(showItem); }
void SniAdaptor::SecondaryActivate(int, int) { m_tray->activateItem(showItem); }
void SniAdaptor::ContextMenu(int, int) {}
void SniAdaptor::Scroll(int, const QString &) {}

// ---- com.canonical.dbusmenu --------------------------------------------

MenuAdaptor::MenuAdaptor(QObject *object, TransferTray *tray) : QDBusAbstractAdaptor(object), m_tray(tray) {
    setAutoRelaySignals(false);
}

QVariantMap MenuAdaptor::itemProperties(int id) const {
    if (id == showItem) return {{QStringLiteral("label"), m_tray->showLabel()}, {QStringLiteral("enabled"), true}};
    if (id == cancelItem) return {{QStringLiteral("label"), m_tray->cancelLabel()}, {QStringLiteral("enabled"), true}};
    return {{QStringLiteral("children-display"), QStringLiteral("submenu")}};
}

uint MenuAdaptor::GetLayout(int parentId, int recursionDepth, const QStringList &, MenuLayout &layout) {
    layout = MenuLayout{parentId, itemProperties(parentId), {}};
    if (parentId == 0 && recursionDepth != 0) {
        for (int id : {showItem, cancelItem}) layout.children << MenuLayout{id, itemProperties(id), {}};
    }
    return m_revision;
}

MenuItemPropertiesList MenuAdaptor::GetGroupProperties(const QList<int> &ids, const QStringList &) {
    MenuItemPropertiesList out;
    for (int id : ids) out << MenuItemProperties{id, itemProperties(id)};
    return out;
}

QDBusVariant MenuAdaptor::GetProperty(int id, const QString &name) { return QDBusVariant(itemProperties(id).value(name)); }

void MenuAdaptor::Event(int id, const QString &eventId, const QDBusVariant &, uint) {
    if (eventId == QStringLiteral("clicked")) m_tray->activateItem(id);
}

QList<int> MenuAdaptor::EventGroup(const MenuEventList &events) {
    QList<int> errors;
    for (const MenuEvent &event : events) {
        if (event.id != showItem && event.id != cancelItem) errors << event.id;
        else Event(event.id, event.eventId, event.data, event.timestamp);
    }
    return errors;
}

bool MenuAdaptor::AboutToShow(int) { return false; }

QList<int> MenuAdaptor::AboutToShowGroup(const QList<int> &, QList<int> &idErrors) {
    idErrors.clear();
    return {};
}

void MenuAdaptor::changed() {
    ++m_revision;
    emit LayoutUpdated(m_revision, 0);
}

// ---- the item ----------------------------------------------------------

TransferTray::TransferTray(QObject *parent) : QObject(parent) {
    static int instance = 0;
    m_serviceName = QStringLiteral("org.kde.StatusNotifierItem-%1-%2")
                        .arg(QCoreApplication::applicationPid())
                        .arg(++instance);
    registerTypes();
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        // A shell that restarts its tray host gets the item again.
        auto *watcher = new QDBusServiceWatcher(watcherService, bus, QDBusServiceWatcher::WatchForRegistration, this);
        connect(watcher, &QDBusServiceWatcher::serviceRegistered, this, [this] { if (m_registered) announce(); });
    }
}

TransferTray::~TransferTray() { withdraw(); }

void TransferTray::setActive(bool active) {
    if (m_active == active) return;
    m_active = active;
    emit activeChanged();
    if (active) publish();
    else withdraw();
}

void TransferTray::setNeedsAttention(bool attention) {
    if (m_attention == attention) return;
    m_attention = attention;
    emit needsAttentionChanged();
    if (m_sni) emit m_sni->NewStatus(m_sni->status());
}

void TransferTray::setTitle(const QString &title) {
    if (m_title == title) return;
    m_title = title;
    emit titleChanged();
    if (m_sni) emit m_sni->NewTitle();
}

void TransferTray::setToolTip(const QString &toolTip) {
    if (m_toolTip == toolTip) return;
    m_toolTip = toolTip;
    emit toolTipChanged();
    if (m_sni) emit m_sni->NewToolTip();
}

void TransferTray::setShowLabel(const QString &label) {
    if (m_showLabel == label) return;
    m_showLabel = label;
    emit menuChanged();
    if (m_menuAdaptor) m_menuAdaptor->changed();
}

void TransferTray::setCancelLabel(const QString &label) {
    if (m_cancelLabel == label) return;
    m_cancelLabel = label;
    emit menuChanged();
    if (m_menuAdaptor) m_menuAdaptor->changed();
}

void TransferTray::activateItem(int id) {
    if (id == showItem) emit showTransfersRequested();
    else if (id == cancelItem) emit cancelAllRequested();
}

void TransferTray::publish() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (m_registered || !bus.isConnected()) return;
    m_item = new QObject(this);
    m_menu = new QObject(this);
    m_sni = new SniAdaptor(m_item, this);
    m_menuAdaptor = new MenuAdaptor(m_menu, this);
    if (!bus.registerObject(QStringLiteral("/StatusNotifierItem"), m_item, QDBusConnection::ExportAdaptors)
        || !bus.registerObject(QStringLiteral("/MenuBar"), m_menu, QDBusConnection::ExportAdaptors)
        || !bus.registerService(m_serviceName)) {
        qWarning() << "hensou-files: cannot register the transfer item on the session bus";
        withdraw();
        return;
    }
    m_registered = true;
    emit registeredChanged();
    announce();
}

void TransferTray::announce() {
    QDBusMessage call = QDBusMessage::createMethodCall(watcherService, QStringLiteral("/StatusNotifierWatcher"),
                                                       watcherService, QStringLiteral("RegisterStatusNotifierItem"));
    call << m_serviceName;
    // No watcher (no tray host yet) is normal; the service watcher retries.
    QDBusConnection::sessionBus().call(call, QDBus::NoBlock);
}

void TransferTray::withdraw() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        if (m_registered) bus.unregisterService(m_serviceName);
        bus.unregisterObject(QStringLiteral("/StatusNotifierItem"));
        bus.unregisterObject(QStringLiteral("/MenuBar"));
    }
    delete m_item;
    delete m_menu;
    m_item = nullptr;
    m_menu = nullptr;
    if (m_registered) {
        m_registered = false;
        emit registeredChanged();
    }
}
