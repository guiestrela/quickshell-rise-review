# V1/V2: orientation, styles, and panels

Use this reference when changing Rise's vertical presentation. Both V1 and V2 support Top/Bottom/Left/Right. Confirm the current values in the code.

Paths beginning with `variants/V2/...` are relative to the repository root.
Other module paths are relative to `variants/V2/`.

## V1: vertical surfaces

V1 uses `variants/V1/modules/VerticalBarContent.qml`, with surfaces for each
run defined by the saved splits, a visual `pillWidth` of 32 px, and a reserved
`verticalBarWidth` of 40 px. Preserve grouping, borders, and effects between
runs when changing widgets.

`standardizeSurface()` removes backgrounds and borders from widgets' direct
children; it does not reach backgrounds loaded through a `Loader`.
The V1 wrappers for `CpuTemperatureWidget.qml` and `StorageWidget.qml` use
`backgroundComponent: null` when `barVertical` is true to avoid double frames.
Preserve their own backgrounds in horizontal mode. When adding shared widgets,
check which component draws the surface before adding another background or
border.

IDs differ between variants: temperature/storage use G20/G21 in V1 and
G16/G18 in V2. Do not transfer orders or preferences between these IDs.

## Where to make changes

- `variants/V2/Theme.qml`: persisted position in `barPosition`, `barVertical`, width derived from `verticalBarWidth`, colors, and preferences. Frost changes `barBg`; panel and tooltip backgrounds use `bg` to remain readable. Preserve the cache field previously used by Notch Frost.
- `variants/V2/BarSlot.qml`: owns slot models, saved order, lifecycle controller, and the window for each output. The horizontal presentation and `modules/VerticalBarContent.qml` reuse these models; only the active presentation instantiates widgets. Width, `exclusiveZone`, the mask, and `VariantRoot.barSize` must agree.
- `VerticalBarContent.qml`: separate columns for Left/top, Center/middle, and Right/bottom. `Instantiator` creates delegates in their corresponding columns; avoid reparenting Repeater delegates between different parents. Columns measure actual widgets, including workspaces with variable heights. Layouts exceeding the available height scroll without overlapping regions.
- `modules/SidePanelPositioner.qml`: applies X/Y bindings only in vertical orientation and restores horizontal bindings when leaving it. Every new panel attached to the bar needs this adaptation, including components shared with V1 that expose a `surfaceHost`.
- `modules/AiPanelSurface.qml`: renders the rounded background on the sides and the connected outline in horizontal mode. Hiding the entire component to remove the connector also removes the background of transparent cards.

## Visual and interaction contracts

In V2, `verticalBarWidth` is 36 px for Full/Dock/Notch and 40 px for Fit.
Fit keeps an outer gap of 2 px on each side; content uses side margins of
1 px, preserving 34 px internally across all styles. When changing the width,
check widgets, the mask, the exclusive zone, and panel anchors; also update
the geometry and expected positions in test fixtures.

Full occupies the available height; Fit has an outer margin; Dock touches the edge; Notch adds curves at the ends. Notch curves must fit within the input mask. Changing position preserves the selected style.

The vertical G8 group uses icon-only weather and a compact clock. Publish distinct Y anchors for weather and calendar based on the actual child positions. Respect `clock12h` and `widgetContentColor` so time and weather follow the group's contrast. Do not add temperature or other elements without considering the user's choice.

Workspaces reuse `WorkspaceWidget.qml`: a column on the sides and a row in Top/Bottom; preserve styles and the 5/10/active modes. The animated frame must follow the correct axis. Do not overwrite saved compactness settings to achieve vertical mode: derive the presentation from `barVertical`.

Drag operations capture source and destination before changing models: the change may destroy the delegate. Do not access the delegate after the swap. Preserve anchor isolation and window recovery for each output.

## Evidence and tests

Run relevant tests without touching real accounts, monitors, or services:

```bash
python3 tests/test-vertical-bar-layout.py
python3 tests/test-v1-vertical-bar.py
python3 tests/test-vertical-workspaces.py
python3 tests/v2-default-layout-regression.py
node --test tests/bar-style-settings.test.mjs
python3 tests/test-bar-style-preview.py´
```

The layout test uses the real workspace and panel surface with inert service widgets. It validates overlap, resizing, Full/Fit/Dock/Notch, anchors, and horizontal restoration. Rendered background sampling uses `magick`. Other tests require `qs`, Qt/QML, and Node as specified by the runner. Also reject `ERROR qml:`: a later `Qt.quit()` can mask an earlier `Qt.exit(1)`.

Lint and offscreen fixtures do not prove physical interaction, multiple outputs, or actual dragging. After applying changes to the installation, validate the plugin, check `omarchy-shell shell ping`, and inspect the PID's own log. Report separately what was tested and what still requires visual inspection; do not change user preferences merely to obtain evidence.
