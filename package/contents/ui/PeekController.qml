/*
 * SPDX-FileCopyrightText: 2022 ivan (@ratijas) tkachenko <me@ratijas.tk>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick 2.0
import org.kde.plasma.plasmoid 2.0

Item {
	id: controller

	property string titleInactive: i18nc("@action:button", "Peek at Desktop")
	property string titleActive: Plasmoid.containment.corona.editMode ? titleInactive : i18nc("@action:button", "Stop Peeking at Desktop")
	property string descriptionActive: i18nc("@info:tooltip", "Moves windows back to their original positions")
	property string descriptionInactive: i18nc("@info:tooltip", "Temporarily shows the desktop by moving windows away")
	property bool active: Plasmoid.shellInterface ? Plasmoid.shellInterface.showDesktop : false

	// Ensure the state is synchronized with the shell interface
	onActiveChanged: {
		if (Plasmoid.shellInterface && Plasmoid.shellInterface.showDesktop !== active) {
			Plasmoid.shellInterface.showDesktop = active;
		}
	}

	// Sync with shell interface when it becomes available
	Connections {
		target: Plasmoid.shellInterface
		function onShowDesktopChanged() {
			active = Plasmoid.shellInterface.showDesktop;
		}
	}

	// Initialize the state when component is created
	Component.onCompleted: {
		if (Plasmoid.shellInterface) {
			active = Plasmoid.shellInterface.showDesktop;
		}
	}

	function toggle() {
		if (Plasmoid.shellInterface) {
			Plasmoid.shellInterface.showDesktop = !Plasmoid.shellInterface.showDesktop;
			active = Plasmoid.shellInterface.showDesktop;
		}
	}

	// Handle widget clicks
	Plasmoid.onActivated: toggle()
}
