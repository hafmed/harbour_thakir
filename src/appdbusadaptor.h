#ifndef APPDBUSADAPTOR_H
#define APPDBUSADAPTOR_H

#include <QObject>
#include <QQuickView>
#include <QVariantMap>
#include <QStringList>
#include <QDBusAbstractAdaptor>
#include <QDebug>

class AppDBusAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.hafsoftdz.harbour_thakir")
public:
    explicit AppDBusAdaptor(QQuickView *view, QObject *parent)
        : QDBusAbstractAdaptor(parent), m_view(view) {}

public slots:
    void open()
    {
        qDebug() << "AppDBusAdaptor: open() called";
        activateWindow();
    }

    void onActionInvoked(uint id, const QString &action)
    {
        Q_UNUSED(id);
        Q_UNUSED(action);
        qDebug() << "AppDBusAdaptor: onActionInvoked called for notification id" << id << "action:" << action;
        activateWindow();
    }

    void activate()
    {
        qDebug() << "AppDBusAdaptor: activate() called";
        activateWindow();
    }

    void show()
    {
        qDebug() << "AppDBusAdaptor: show() called";
        activateWindow();
    }

    void Activate(const QVariantMap &platform_data)
    {
        Q_UNUSED(platform_data);
        qDebug() << "AppDBusAdaptor: Activate() called";
        activateWindow();
    }

private:
    void activateWindow()
    {
        if (m_view) {
            m_view->setWindowState(Qt::WindowActive);
            m_view->show();
            m_view->raise();
            m_view->requestActivate();
        }
    }

    QQuickView *m_view;
};

class FreedesktopAppAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Application")
public:
    explicit FreedesktopAppAdaptor(QQuickView *view, QObject *parent)
        : QDBusAbstractAdaptor(parent), m_view(view) {}

public slots:
    void Activate(const QVariantMap &platform_data)
    {
        Q_UNUSED(platform_data);
        qDebug() << "FreedesktopAppAdaptor: Activate() called";
        if (m_view) {
            m_view->setWindowState(Qt::WindowActive);
            m_view->show();
            m_view->raise();
            m_view->requestActivate();
        }
    }

    void Open(const QStringList &uris, const QVariantMap &platform_data)
    {
        Q_UNUSED(uris);
        Activate(platform_data);
    }

    void ActivateAction(const QString &action_name, const QVariantList &parameter, const QVariantMap &platform_data)
    {
        Q_UNUSED(action_name);
        Q_UNUSED(parameter);
        Activate(platform_data);
    }

private:
    QQuickView *m_view;
};

#endif // APPDBUSADAPTOR_H
