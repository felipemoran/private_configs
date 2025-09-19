on tensorWorkedTime()
	set now to current date
	set currentTime to (time of now)

	if currentTime < (4 * hours) then
		-- If it's before 4 AM today, use 4 AM yesterday
		set last4AM to now - (1 * days)
	else
		-- If it's 4 AM or later today, use 4 AM today
		set last4AM to now
	end if

	-- Set the time of last4AM to 4 AM
	set time of last4AM to (4 * hours)

	tell application "TimingHelper"
		set summary to times per project of (get time summary between last4AM and now)
		try
			set tensor to tensor of summary
		on error
			-- No tensor project found, return 0 seconds
			set tensor to 0
		end try
	end tell

	return tensor
end tensorWorkedTime

on formatNumberToTwoDigits(n)
	if n < 10 then
		return "0" & n
	else
		return n as string
	end if
end formatNumberToTwoDigits

on secondsToTimeString(seconds_)
	set hours to (seconds_ div 3600)
	set minutes to (seconds_ mod 3600) div 60

	return formatNumberToTwoDigits(hours) & ":" & formatNumberToTwoDigits(minutes)
end secondsToTimeString

on calcRemainingWorkTime(workedTime)
	set remaining to 8 * 3600 - workedTime
	if remaining < 0 then
		return 0
	end if
	return remaining
end calcRemainingWorkTime

on calcFinishTime(remaining)
	set now to current date
	set finishTime to now + remaining
	return time of finishTime
end calcFinishTime

set workedTime to tensorWorkedTime()
set remaining to calcRemainingWorkTime(workedTime)

set workedTimeStr to secondsToTimeString(workedTime)
set finishStr to "-"

if remaining > 0 then
	set finishStr to secondsToTimeString(calcFinishTime(remaining))
end if

set text_ to workedTimeStr & "\\n(" & finishStr & ")"

return "{'text': '" & text_ & "', 'font_size': 9}"
