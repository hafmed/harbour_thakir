#ifndef PLAYBACKCONTROLLER_H
#define PLAYBACKCONTROLLER_H

#include <QObject>
#include <QMediaPlayer>

// Exposed to QML as "playback" only in the headless --play <prayer>
// launch (see main.cpp). Lets the on-screen Stop page actually silence
// the athan instead of only relying on the 3-minute safety timeout.
class PlaybackController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString prayer READ prayer CONSTANT)
public:
    explicit PlaybackController(const QString &prayer, QMediaPlayer *player, QObject *parent = nullptr);

    QString prayer() const;

public slots:
    // Stops playback; the caller (main.cpp) is responsible for quitting
    // the application once this is invoked - see the stopped() signal.
    void stop();

signals:
    void stopped();

private:
    QString m_prayer;
    QMediaPlayer *m_player;
};

#endif // PLAYBACKCONTROLLER_H
