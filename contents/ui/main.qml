/*
	SPDX-FileCopyrightText: 2014 Ashish Madeti <ashishmadeti@gmail.com>
	SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
	SPDX-FileCopyrightText: 2019 Chris Holland <zrenfire@gmail.com>
	SPDX-FileCopyrightText: 2022 ivan (@ratijas) tkachenko <me@ratijas.tk>

	SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.3

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid

PlasmoidItem {
	id: root

	preferredRepresentation: fullRepresentation
	toolTipSubText: activeController.description

	AppletConfig {
		id: config
	}

	Plasmoid.icon: "transform-move"
	Plasmoid.title: activeController.title
	Plasmoid.onActivated: {
		if (isPeeking) {
			isPeeking = false;
			peekController.toggle();
		}
		activeController.toggle();
	}

	Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

	Layout.minimumWidth: Kirigami.Units.iconSizes.medium
	Layout.minimumHeight: Kirigami.Units.iconSizes.medium

	Layout.maximumWidth: vertical ? Layout.minimumWidth : Math.max(1, Plasmoid.configuration.size)
	Layout.maximumHeight: vertical ? Math.max(1, Plasmoid.configuration.size) : Layout.minimumHeight

	Layout.preferredWidth: Layout.maximumWidth
	Layout.preferredHeight: Layout.maximumHeight

	Plasmoid.constraintHints: Plasmoid.CanFillArea

	readonly property bool inPanel: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge]
			.includes(Plasmoid.location)

	readonly property bool vertical: Plasmoid.location === PlasmaCore.Types.RightEdge || Plasmoid.location === PlasmaCore.Types.LeftEdge

	readonly property Controller primaryController: {
		if (Plasmoid.configuration.click_action == "minimizeall") {
			return minimizeAllController;
		} else if (Plasmoid.configuration.click_action == "showdesktop") {
			return peekController;
		} else {
			return commandController;
		}
	}

	readonly property Controller activeController: {
		if (minimizeAllController.active) {
			return minimizeAllController;
		} else {
			return primaryController;
		}
	}

	property bool isPeeking: false

	// --- Desktop Pill styling: solid KDE Plasma accent color, no outline ----
	// Kirigami.Theme.highlightColor already reflects Plasma's global accent
	// color setting. The pill is transparent at rest - including while the
	// action is active (desktop shown / windows minimized) - and only turns
	// solid on hover or press. Never a semi-transparent tint: it's either
	// fully solid or fully invisible.
	readonly property color accentColor: Kirigami.Theme.highlightColor

	// Returns the user's custom override for `key` when accent-color mode is
	// disabled and a value was actually set, otherwise `fallback`.
	function customOr(key, fallback) {
		if (!Plasmoid.configuration.useAccentColor && Plasmoid.configuration[key]) {
			return Plasmoid.configuration[key];
		}
		return fallback;
	}

	// Base solid accent color of the pill, used for hover/pressed/active shades.
	readonly property color pillBaseColor: customOr('activeColor', accentColor)

	readonly property color pillIdleColor: "transparent"
	readonly property color pillHoverColor: customOr('hoveredColor', Qt.lighter(pillBaseColor, 1.18))
	readonly property color pillPressedColor: customOr('pressedColor', Qt.darker(pillBaseColor, 1.3))

	readonly property color pillDisplayColor: {
		if (mouseArea.state === "pressed") {
			return pillPressedColor;
		}
		if (mouseArea.state === "hover") {
			return pillHoverColor;
		}
		// Idle: always transparent, even while the action is active (desktop
		// shown / windows minimized) - the accent color only shows up on
		// direct interaction (hover/press).
		return pillIdleColor;
	}

	MouseArea {
		id: mouseArea
		anchors.fill: parent

		activeFocusOnTab: true
		hoverEnabled: true

		onClicked: Plasmoid.activated();

		onEntered: {
			if (Plasmoid.configuration.peekingEnabled)
				peekTimer.start();
		}
		onExited: {
			peekTimer.stop();
			if (isPeeking) {
				isPeeking = false;
				peekController.toggle();
			}
		}

		// org.kde.plasma.volume
		property int wheelDelta: 0
		onWheel: wheel => {
			const delta = (wheel.inverted ? -1 : 1) * (wheel.angleDelta.y ? wheel.angleDelta.y : -wheel.angleDelta.x);
			wheelDelta += delta;
			// Magic number 120 for common "one click"
			// See: https://qt-project.org/doc/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
			while (wheelDelta >= 120) {
				wheelDelta -= 120;
				performMouseWheelUp();
			}
			while (wheelDelta <= -120) {
				wheelDelta += 120;
				performMouseWheelDown();
			}
		}

		Keys.onPressed: {
			switch (event.key) {
			case Qt.Key_Space:
			case Qt.Key_Enter:
			case Qt.Key_Return:
			case Qt.Key_Select:
				Plasmoid.activated();
				break;
			}
		}

		Accessible.name: Plasmoid.title
		Accessible.description: toolTipSubText
		Accessible.role: Accessible.Button

		PeekController {
			id: peekController
		}

		MinimizeAllController {
			id: minimizeAllController
		}

		CommandController {
			id: commandController
		}

		Kirigami.Icon {
			anchors.fill: parent
			active: mouseArea.containsMouse || activeController.active
			visible: Plasmoid.containment.corona.editMode
			source: Plasmoid.icon
		}

		// also activate when dragging an item over the plasmoid so a user can easily drag data to the desktop
		DropArea {
			anchors.fill: parent
			onEntered: activateTimer.start()
			onExited: activateTimer.stop()
		}

		Timer {
			id: activateTimer
			interval: 250 // to match TaskManager
			onTriggered: Plasmoid.activated()
		}

		Timer {
			id: peekTimer
			interval: Plasmoid.configuration.peekingThreshold
			onTriggered: {
				if (!minimizeAllController.active && !peekController.active) {
					isPeeking = true;
					peekController.toggle();
				}
			}
		}

		state: {
			if (mouseArea.containsPress) {
				return "pressed";
			} else if (mouseArea.containsMouse || mouseArea.activeFocus) {
				return "hover";
			} else {
				return "normal";
			}
		}

		// Desktop Pill visual: a single, always-solid, fully-opaque accent-
		// colored capsule. Its thickness is measured on the SAME axis as
		// "Size" (width in a horizontal panel, height in a vertical panel) -
		// i.e. it's a thin line running along the panel's thickness, not a
		// wide block. It is its own independently configurable size and does
		// NOT affect the MouseArea above, which still fills the whole widget
		// so the clickable/hoverable area stays exactly as large as before,
		// regardless of how thin or discreet the visible pill is drawn.
		Rectangle {
			id: pill

			readonly property int thickness: Math.max(1, Plasmoid.configuration.pillThickness)
			readonly property int length: Math.max(1, Plasmoid.configuration.pillLength)

			anchors.centerIn: parent
			width: vertical ? Math.min(length, parent.width) : Math.min(thickness, parent.width)
			height: vertical ? Math.min(thickness, parent.height) : Math.min(length, parent.height)

			radius: Math.max(0, Math.min(Plasmoid.configuration.cornerRadius, width / 2, height / 2))

			color: root.pillDisplayColor
			// No border/outline - just the solid capsule.

			Behavior on color {
				ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
			}
			Behavior on width {
				NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
			}
			Behavior on height {
				NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
			}
		}

		PlasmaCore.ToolTipArea {
			id: toolTip
			anchors.fill: parent
			mainText: Plasmoid.title
			subText: toolTipSubText
			textFormat: Text.PlainText
		}
	}

	// https://invent.kde.org/plasma/plasma5support/-/tree/master/src/declarativeimports/datasource.h
	Plasma5Support.DataSource {
		id: executeSource
		engine: "executable"
		connectedSources: []

		property var listeners: ({}) // Empty Map

		signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)

		function getUniqueId(cmd) {
			// Note: we assume that 'cmd' is executed quickly so that a previous call
			// with the same 'cmd' has already finished (otherwise no new cmd will be
			// added because it is already in the list)
			// Workaround: We append spaces onto the user's command to workaround this.
			var cmd2 = cmd
			for (var i = 0; i < 10; i++) {
				if (connectedSources.includes(cmd2)) {
					cmd2 += ' '
				}
			}
			return cmd2
		}
		function exec(cmd, callback) {
			const cmdId = getUniqueId(cmd)
			if (typeof callback === 'function') {
				if (listeners[cmdId]) {
					exited.disconnect(listeners[cmdId])
					delete listeners[cmdId]
				}
				var listener = execCallback.bind(executeSource, callback)
				listeners[cmdId] = listener
			}
			connectSource(cmdId)
		}
		function execCallback(callback, cmd, exitCode, exitStatus, stdout, stderr) {
			delete listeners[cmd]
			callback(cmd, exitCode, exitStatus, stdout, stderr)
		}
		onNewData: function(sourceName, data) {
			const cmd = sourceName
			const exitCode = data["exit code"]
			const exitStatus = data["exit status"]
			const stdout = data["stdout"]
			const stderr = data["stderr"]
			const listener = listeners[cmd]
			if (listener) {
				listener(cmd, exitCode, exitStatus, stdout, stderr)
			}
			exited(cmd, exitCode, exitStatus, stdout, stderr)
			disconnectSource(sourceName) // cmd finished
		}
	}

	function exec(cmd) {
		let cmd2 = executeSource.getUniqueId(cmd)
		if (config.isOpenSUSE) {
			cmd2 = cmd2.replace(/^qdbus /, 'qdbus6 ')
		}
		executeSource.connectSource(cmd2)
	}

	function performMouseWheelUp() {
		root.exec(Plasmoid.configuration.mousewheel_up)
	}

	function performMouseWheelDown() {
		root.exec(Plasmoid.configuration.mousewheel_down)
	}

	Plasmoid.contextualActions: [
		PlasmaCore.Action {
			visible: Plasmoid.immutability != PlasmaCore.Types.SystemImmutable
			readonly property bool isLocked: Plasmoid.immutability != PlasmaCore.Types.Mutable
			text: isLocked ? i18n("Unlock Widgets") : i18n("Lock Widgets")
			icon.name: isLocked ? "object-unlocked" : "object-locked"
			onTriggered: {
				if (Plasmoid.immutability == PlasmaCore.Types.Mutable) {
					Plasmoid.containment.corona.setImmutability(PlasmaCore.Types.UserImmutable)
				} else if (Plasmoid.immutability == PlasmaCore.Types.UserImmutable) {
					Plasmoid.containment.corona.setImmutability(PlasmaCore.Types.Mutable)
				} else {
					// ignore SystemImmutable
				}
			}
		},
		PlasmaCore.Action {
			text: minimizeAllController.titleInactive
			checkable: true
			checked: minimizeAllController.active
			toolTip: minimizeAllController.description
			enabled: !peekController.active
			onTriggered: minimizeAllController.toggle()
		},
		PlasmaCore.Action {
			text: peekController.titleInactive
			checkable: true
			checked: peekController.active
			toolTip: peekController.description
			enabled: !minimizeAllController.active
			onTriggered: peekController.toggle()
		}
	]

	function detectSUSE() {
		executeSource.exec('env | grep VENDOR', function(cmd, exitCode, exitStatus, stdout, stderr) {
			if (stdout.replace(/\n/g, ' ').trim() == 'VENDOR=suse') {
				config.isOpenSUSE = true
			}
			// console.log('config.isOpenSUSE', config.isOpenSUSE)
		})
	}

	Component.onCompleted: {
		detectSUSE()
	}
}
