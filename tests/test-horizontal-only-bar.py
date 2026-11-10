from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures = []

for variant in ("V1", "V2"):
    theme = (ROOT / f"variants/{variant}/Theme.qml").read_text()
    bar_slot = (ROOT / f"variants/{variant}/BarSlot.qml").read_text()
    control = (ROOT / f"variants/{variant}/panels/ControlPanel.qml").read_text()
    if "readonly property bool barVertical: false" not in theme:
        failures.append(f"{variant}: side orientation is not disabled")
    if '["top", "bottom"].indexOf(bp) < 0' not in theme:
        failures.append(f"{variant}: side positions are not rejected when loading preferences")
    if 'label: "Left"' in control or 'label: "Right"' in control:
        failures.append(f"{variant}: control panel still offers side positions")
    if "VerticalBarContent" in bar_slot or "verticalLoader" in bar_slot:
        failures.append(f"{variant}: BarSlot still references the vertical rail")
    if (ROOT / f"variants/{variant}/modules/VerticalBarContent.qml").exists():
        failures.append(f"{variant}: vertical rail source file still exists")

for name in ("VerticalBarContentLogic.js", "VerticalBarContentValuesLogic.js"):
    if (ROOT / "shared/logic" / name).exists():
        failures.append(f"shared/logic/{name} still exists")

if failures:
    print("FAIL: horizontal-only bar contract not met")
    print("\n".join(f"- {failure}" for failure in failures))
    raise SystemExit(1)

print("PASS: both variants are horizontal-only; vertical components and helpers are absent")
