import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Services

// Headset pill for DankBar, backed by the `headsetcontrol` CLI (>= 4.x).
//
// The bar shows the battery; the popout sets sidetone, auto-off and the EQ
// preset. Most headsets (the G PRO X 2 included) cannot report sidetone or
// auto-off back, so the last values set here are remembered in plugin data
// and shown as the current ones.
PluginComponent {
    id: root

    readonly property int pollSeconds: 60

    // Last JSON report from `headsetcontrol -o json`, first device only.
    property var device: null
    property bool cliMissing: false

    readonly property bool connected: device !== null
    readonly property var caps: device ? (device.capabilities_str || []) : []
    readonly property var battery: device ? device.battery : null
    readonly property bool batteryKnown: battery !== null && battery !== undefined && battery.status !== "BATTERY_UNAVAILABLE" && battery.level >= 0
    readonly property bool charging: batteryKnown && battery.status === "BATTERY_CHARGING"
    readonly property var presetNames: device && device.equalizer_presets ? Object.keys(device.equalizer_presets) : []

    property int sidetone: pluginService ? pluginService.loadPluginData(pluginId, "sidetone", 0) : 0
    property int inactiveTime: pluginService ? pluginService.loadPluginData(pluginId, "inactiveTime", 0) : 0
    property int presetIndex: pluginService ? pluginService.loadPluginData(pluginId, "presetIndex", -1) : -1

    readonly property var inactiveChoices: [0, 10, 30, 60, 90]

    function has(cap) {
        return caps.indexOf(cap) !== -1;
    }

    function remember(key, value) {
        if (pluginService)
            pluginService.savePluginData(pluginId, key, value);
    }

    function refresh() {
        Proc.runCommand("headsetControl.status", ["sh", "-c", "command -v headsetcontrol >/dev/null || exit 127; exec headsetcontrol -o json"], (out, code) => {
            if (code === 127) {
                root.cliMissing = true;
                root.device = null;
                return;
            }
            root.cliMissing = false;
            try {
                const report = JSON.parse(out);
                const devices = (report.devices || []).filter(d => d.status === "success");
                root.device = devices.length > 0 ? devices[0] : null;
            } catch (e) {
                root.device = null;
            }
        }, 100);
    }

    function apply(key, args, value) {
        Proc.runCommand("headsetControl." + key, ["headsetcontrol"].concat(args), (out, code) => {
            if (code === 0)
                root.remember(key, value);
            else
                ToastService.showError(I18n.tr("Headset"), out.trim() || ("headsetcontrol " + args.join(" ")));
        }, 300);
    }

    function batteryIcon() {
        if (!connected)
            return "headset_off";
        if (charging)
            return "battery_charging_full";
        return "headphones";
    }

    function batteryColor() {
        if (!batteryKnown || charging)
            return Theme.surfaceText;
        if (battery.level <= 15)
            return Theme.error;
        if (battery.level <= 30)
            return Theme.warning;
        return Theme.surfaceText;
    }

    function batteryText() {
        if (cliMissing)
            return "—";
        if (!connected)
            return "";
        return batteryKnown ? battery.level + "%" : "";
    }

    function remainingText() {
        if (!batteryKnown)
            return connected ? I18n.tr("Battery unknown (headset off?)") : "";
        if (charging)
            return I18n.tr("Charging") + " · " + battery.level + "%";
        const min = battery.time_to_empty_min;
        if (min === undefined || min < 0)
            return battery.level + "%";
        const h = Math.floor(min / 60);
        return battery.level + "% · " + (h > 0 ? h + " h " : "") + (min % 60) + " min";
    }

    Timer {
        interval: root.pollSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DIcon {
                name: root.batteryIcon()
                color: root.batteryColor()
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: text !== ""
                text: root.batteryText()
                color: root.batteryColor()
                font.pixelSize: root.textSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DIcon {
                name: root.batteryIcon()
                color: root.batteryColor()
                size: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: text !== ""
                text: root.batteryText()
                color: root.batteryColor()
                font.pixelSize: root.textSize
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 380
    popoutHeight: 420

    popoutContent: Component {
        PopoutComponent {
            headerText: root.connected ? root.device.device : I18n.tr("Headset")
            detailsText: root.cliMissing ? I18n.tr("headsetcontrol is not installed") : (root.connected ? root.remainingText() : I18n.tr("No supported headset connected"))

            Component.onCompleted: root.refresh()

            Column {
                width: parent.width
                spacing: Theme.spacingL
                visible: root.connected

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.has("sidetone")

                    StyledText {
                        text: I18n.tr("Sidetone (hear your own voice)")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    DSlider {
                        width: parent.width
                        minimum: 0
                        maximum: 100
                        unit: "%"
                        startIcon: "mic"
                        // headsetcontrol takes 0-128.
                        value: Math.round(root.sidetone * 100 / 128)
                        onSliderDragFinished: finalValue => {
                            const level = Math.round(finalValue * 128 / 100);
                            root.sidetone = level;
                            root.apply("sidetone", ["-s", String(level)], level);
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.has("inactive time")

                    StyledText {
                        text: I18n.tr("Turn off when idle")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    DButtonGroup {
                        width: parent.width
                        fillWidth: true
                        size: "small"
                        checkEnabled: false
                        model: root.inactiveChoices.map(m => m === 0 ? I18n.tr("Never") : m + " min")
                        currentIndex: Math.max(0, root.inactiveChoices.indexOf(root.inactiveTime))
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            const minutes = root.inactiveChoices[index];
                            root.inactiveTime = minutes;
                            root.apply("inactiveTime", ["-i", String(minutes)], minutes);
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.has("equalizer preset") && root.presetNames.length > 0

                    StyledText {
                        text: I18n.tr("Equalizer preset")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    DButtonGroup {
                        width: parent.width
                        fillWidth: true
                        size: "small"
                        checkEnabled: false
                        model: root.presetNames
                        currentIndex: root.presetIndex
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            root.presetIndex = index;
                            root.apply("presetIndex", ["-p", String(index)], index);
                        }
                    }
                }
            }
        }
    }
}
