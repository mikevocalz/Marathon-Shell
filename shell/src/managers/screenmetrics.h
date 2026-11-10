#pragma once

#include <QObject>
#include <QPointer>

class QScreen;
class QWindow;

class ScreenMetrics : public QObject {
    Q_OBJECT
    Q_PROPERTY(int width READ width NOTIFY metricsChanged)
    Q_PROPERTY(int height READ height NOTIFY metricsChanged)
    Q_PROPERTY(qreal dpi READ dpi NOTIFY metricsChanged)
    Q_PROPERTY(qreal refreshRate READ refreshRate NOTIFY metricsChanged)
    Q_PROPERTY(qreal devicePixelRatio READ devicePixelRatio NOTIFY metricsChanged)

  public:
    explicit ScreenMetrics(QObject *parent = nullptr);

    // Follow the shell's viewport and the display it is on. With no window,
    // report the primary display so startup and headless callers still work.
    void attachToWindow(QWindow *window);

    int  width() const {
        return m_width;
    }
    int height() const {
        return m_height;
    }
    qreal dpi() const {
        return m_dpi;
    }
    qreal refreshRate() const {
        return m_refreshRate;
    }
    qreal devicePixelRatio() const {
        return m_devicePixelRatio;
    }

    static qreal computeDpi(QScreen *screen);

  signals:
    void metricsChanged();

  protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

  private:
    void              attachToScreen(QScreen *screen);
    void              updateMetrics();

    QPointer<QWindow> m_window;
    QPointer<QScreen> m_screen;
    int               m_width            = 0;
    int               m_height           = 0;
    qreal             m_dpi              = 0.0;
    qreal             m_refreshRate      = 0.0;
    qreal             m_devicePixelRatio = 1.0;
};
