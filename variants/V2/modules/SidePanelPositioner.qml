import QtQuick

Item {
    id: positioner
    required property var root
    required property Item target
    required property string anchorName
    visible: false
    Binding {
        target: positioner.target
        property: "x"
        when: positioner.root.barVertical
        value: positioner.root.barPosition === "left"
            ? positioner.root.verticalBarWidth + 6
            : Math.max(6, positioner.target.parent.width - positioner.root.verticalBarWidth - positioner.target.width - 6)
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: positioner.target
        property: "y"
        when: positioner.root.barVertical
        value: Math.max(6, Math.min(positioner.target.parent.height - positioner.target.height - 6,
            positioner.root.verticalAnchorY(positioner.anchorName) - positioner.target.height / 2))
        restoreMode: Binding.RestoreBindingOrValue
    }
}
