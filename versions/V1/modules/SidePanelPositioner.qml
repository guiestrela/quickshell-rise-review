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
        when: positioner.enabled && positioner.root.barVertical === true
        value: !when ? 0 : positioner.root.barPosition === "left"
            ? positioner.root.verticalBarWidth + 8
            : Math.max(8, positioner.target.parent.width - positioner.root.verticalBarWidth - positioner.target.width - 8)
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: positioner.target
        property: "y"
        when: positioner.enabled && positioner.root.barVertical === true
        value: !when ? 0 : Math.max(8, Math.min(positioner.target.parent.height - positioner.target.height - 8,
            positioner.root.verticalAnchorY(positioner.anchorName) - positioner.target.height / 2))
        restoreMode: Binding.RestoreBindingOrValue
    }
}
