import QtQuick
Rectangle {
    property var borderSpec: ({width:0,color:"transparent"})
    border.width: borderSpec.width || 0
    border.color: borderSpec.color || "transparent"
}
