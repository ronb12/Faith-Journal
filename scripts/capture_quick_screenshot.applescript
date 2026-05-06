-- Faith Journal macOS - Quick Single Screenshot (No Dialogs)
-- Captures the current Faith Journal window immediately - run when app is on desired screen
-- Usage: Run this while Faith Journal macOS is the frontmost app and showing the screen you want

on run
	set outputFolder to (system attribute "HOME") & "/Desktop/AppStore-Screenshots"
	do shell script "mkdir -p " & quoted form of outputFolder
	
	-- Try both possible process names
	set appNames to {"Faith Journal macOS", "Faith Journal"}
	set windowID to ""
	set foundName to ""
	tell application "System Events"
		set frontApp to name of first application process whose frontmost is true
		repeat with appName in appNames
			if frontApp is appName then
				tell process appName
					if (count of windows) > 0 then
						set windowID to (id of window 1) as text
						set foundName to appName
						exit repeat
					end if
				end tell
			end if
		end repeat
	end tell
	
	if windowID is "" then
		display dialog "Bring Faith Journal to the front first, then run this again. If it still fails, enable System Settings → Privacy & Security → Accessibility for Terminal/Script Editor." buttons {"OK"} default button 1 with icon stop
		return
	end if
	
	set timestamp to do shell script "date +%Y%m%d_%H%M%S"
	set outputPath to outputFolder & "/FaithJournal_1280x800_" & timestamp & ".png"
	
	-- Capture window only (clean, professional - no desktop)
	do shell script "screencapture -x -l " & windowID & " " & quoted form of outputPath
	
	-- Scale to fit 1280×800 with letterboxing (no content cut off)
	do shell script "if command -v convert >/dev/null 2>&1; then
		convert " & quoted form of outputPath & " -resize 1280x800\\> -background '#e8e8ed' -gravity center -extent 1280x800 " & quoted form of outputPath & "
	else
		sips -Z 1417 " & quoted form of outputPath & " && sips --cropToHeightWidth 800 1280 " & quoted form of outputPath & "
	fi"
	
	display notification "Screenshot saved: 1280×800" with title "Faith Journal"
end run
