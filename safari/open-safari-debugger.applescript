#!/usr/bin/env osascript
-- Open Safari Web Extension Background Content Inspector
-- Navigates to Develop -> Web Extension Background Content -> ipvfoo goodkind.io

tell application "Safari"
	activate
	delay 0.5
end tell

tell application "System Events"
	tell process "Safari"
		-- Click Develop menu
		click menu bar item "Develop" of menu bar 1
		delay 0.3
		
		-- Hover over "Web Extension Background Content"
		tell menu 1 of menu bar item "Develop" of menu bar 1
			-- Get the menu item for Web Extension Background Content
			set webExtensionMenuItem to menu item "Web Extension Background Content"
			
			-- Move to it to show submenu
			perform action "AXPress" of webExtensionMenuItem
			delay 0.5
			
			-- Access the submenu
			tell menu 1 of webExtensionMenuItem
				-- Find menu item containing "goodkind.io"
				set foundItem to false
				repeat with menuItem in menu items
					set itemName to name of menuItem
					if itemName contains "goodkind.io" then
						click menuItem
						set foundItem to true
						exit repeat
					end if
				end repeat
				
				if not foundItem then
					display dialog "Could not find goodkind.io extension in Web Extension Background Content menu" buttons {"OK"} default button "OK"
				end if
			end tell
		end tell
	end tell
end tell

