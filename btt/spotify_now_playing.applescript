-- Function to escape single quotes and backslashes in strings
on escapeString(inputString)
	set escapedString to inputString
	-- First escape backslashes (must be done first)
	set escapedString to my replaceText(escapedString, "\\", "\\\\")
	-- Then escape single quotes
	set escapedString to my replaceText(escapedString, "'", "\\'")
	return escapedString
end escapeString

-- Function to replace text
on replaceText(sourceText, searchText, replaceText)
	set AppleScript's text item delimiters to searchText
	set textItems to text items of sourceText
	set AppleScript's text item delimiters to replaceText
	set replacedText to textItems as string
	set AppleScript's text item delimiters to ""
	return replacedText
end replaceText

set maxLength to 25

set song_ to ""
set artist_ to ""

if application "Spotify" is running then
	tell application "Spotify"
		if player state is playing then
			set artist_ to (get artist of current track) as string
			set song_ to (get name of current track) as string
		else
			return ""
		end if
	end tell
end if

if length of song_ > maxLength then
	set song_ to (text 1 thru maxLength of song_) & "…"
end if

if length of artist_ > maxLength then
	set artist_ to (text 1 thru maxLength of artist_) & "…"
end if

-- Escape the strings before using them in the JSON
set escapedSong to escapeString(song_)
set escapedArtist to escapeString(artist_)

return "{'text': '" & escapedSong & "\\n" & escapedArtist & "', 'font_size': 9}"