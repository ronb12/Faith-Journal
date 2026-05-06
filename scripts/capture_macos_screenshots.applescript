-- Faith Journal macOS - Professional Screenshot Capture for App Store
-- Captures only the app window (no desktop clutter) and saves at correct dimensions
-- Run after building the app; will launch it, wait, and capture the frontmost window

on run argv
	-- Output folder (default: Desktop/AppStore-Screenshots)
	set outputFolder to (system attribute "HOME") & "/Desktop/AppStore-Screenshots"
	if (count of argv) > 0 then
		set outputFolder to item 1 of argv
	end if
	
	-- Bundle ID is most reliable; also try process names
	set bundleID to "com.ronellbradley.FaithJournal.macOS"
	set appNames to {"Faith Journal macOS", "Faith Journal"}
	
	-- Ensure output folder exists
	do shell script "mkdir -p " & quoted form of (POSIX path of outputFolder)
	
	-- Activate the app (use bundle name for launch)
	tell application "Faith Journal macOS" to activate
	
	-- Wait for window: retry up to 15 seconds. Find process by bundle ID first, then by name.
	set windowID to ""
	repeat with waitCount from 1 to 15
		delay 1
		try
			-- Method 1: Find by bundle identifier (most reliable)
			tell application "System Events"
				repeat with p in (every process where background only is false)
					try
						if (bundle identifier of p) is equal to bundleID then
							if (count of windows of p) > 0 then
								set windowID to (id of window 1 of p) as text
								exit repeat
							end if
						end if
					end try
				end repeat
			end tell
		end try
		if windowID is not "" then exit repeat
		try
			-- Method 2: Find by process name
			repeat with appName in appNames
				tell application "System Events"
					tell process appName
						if (count of windows) > 0 then
							set windowID to (id of window 1) as text
							exit repeat
						end if
					end tell
				end tell
			end repeat
		end try
		if windowID is not "" then exit repeat
	end repeat
	
	if windowID is "" then
		display dialog "Could not find Faith Journal window." & return & return & "You must enable Accessibility for the app that runs this script:" & return & "System Settings → Privacy & Security → Accessibility → turn ON for Terminal (if you run from Terminal) or for Cursor (if you run from Cursor)." & return & return & "Then run the script again." buttons {"OK"} default button 1 with icon stop
		return
	end if
	
	-- Capture sequence: take multiple screenshots with pauses for manual navigation
	-- Screenshot 1: Current screen (captured immediately)
	set timestamp to do shell script "date +%Y%m%d_%H%M%S"
	set outputPath to outputFolder & "/FaithJournal_01_Home_" & timestamp & ".png"
	captureWindow(windowID, outputPath)
	
	-- Pause for user to navigate to next screen (optional - user can add more captures)
	display dialog "Screenshot 1 captured: Home/Dashboard" & return & return & "Navigate to the next screen (e.g. Journal, Bible, Devotionals) and click OK to capture another, or Cancel to finish." buttons {"Cancel", "Capture More"} default button 2
	
	if button returned of result is "Capture More" then
		delay 1
		set outputPath to outputFolder & "/FaithJournal_02_Journal_" & timestamp & ".png"
		captureWindow(windowID, outputPath)
		
		display dialog "Screenshot 2 captured." & return & return & "Navigate to another screen and click OK, or Cancel to finish." buttons {"Cancel", "Capture More"} default button 2
		
		if button returned of result is "Capture More" then
			delay 1
			set outputPath to outputFolder & "/FaithJournal_03_Bible_" & timestamp & ".png"
			captureWindow(windowID, outputPath)
			
			display dialog "Screenshot 3 captured." & return & return & "One more? Navigate and click OK." buttons {"Done", "Capture More"} default button 1
			
			if button returned of result is "Capture More" then
				delay 1
				set outputPath to outputFolder & "/FaithJournal_04_" & timestamp & ".png"
				captureWindow(windowID, outputPath)
			end if
		end if
	end if
	
	-- Files already resized in captureWindow handler
	
	display dialog "Screenshots saved and resized to 1280×800 for App Store." & return & return & "Location: " & outputFolder buttons {"OK"} default button 1
end run

on captureWindow(windowID, outputPath)
	-- Use screencapture -l to capture ONLY the app window (clean, no desktop)
	set posixPath to outputPath
	do shell script "screencapture -x -l " & windowID & " " & quoted form of posixPath
	-- Scale to fit 1280×800 with letterboxing (no content cut off); use ImageMagick for padding
	-- If ImageMagick missing, fall back to sips crop
	do shell script "if command -v convert >/dev/null 2>&1; then
		convert " & quoted form of posixPath & " -resize 1280x800\\> -background '#e8e8ed' -gravity center -extent 1280x800 " & quoted form of posixPath & "
	else
		sips -Z 1417 " & quoted form of posixPath & " && sips --cropToHeightWidth 800 1280 " & quoted form of posixPath & "
	fi"
end captureWindow
