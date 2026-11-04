#include "playbackcontroller.h"

PlaybackController::PlaybackController(const QString &prayer, QMediaPlayer *player, QObject *parent)
    : QObject(parent), m_prayer(prayer), m_player(player)
{
}

QString PlaybackController::prayer() const
{
    return m_prayer;
}

void PlaybackController::stop()
{
    if (m_player) {
        m_player->stop();
    }
    emit stopped();
}
