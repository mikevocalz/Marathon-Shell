import QtQuick
import Sailfish.Silica as S

S.Keypad {
    id: root

    _buttonWidth: Math.max(S.Theme.itemSizeSmall, Math.min((3 * S.Theme.itemSizeHuge - 4 * S.Theme.paddingLarge) / 3, Math.floor((width - 2 * _horizontalSpacing) / 3)))
    implicitWidth: 3 * S.Theme.itemSizeSmall + 2 * _horizontalSpacing
}
