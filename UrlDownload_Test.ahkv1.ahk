#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#Include UrlDownload.ahkv1.ahk

; 1. Define a reliable test download URL
testUrl := "https://download.thinkbroadband.com/5MB.zip"

; 2. Resolve the current user's Downloads folder
EnvGet, userProfile, USERPROFILE
downloadsDir := userProfile . "\Downloads"

try 
{
	; Prompt the user
	MsgBox, 64, UrlDownload Test, % "Click OK to start downloading the test file to your Downloads folder:`n`n" . downloadsDir

	; 3. Run the download
	; Parameters: strUrl, strDest, blnOver
	success := urlDownload_File(testUrl, downloadsDir, true)

	if (success)
	{
		MsgBox, 36, Success, % "Download complete!`n`nSaved to: " . downloadsDir . "\1MB.zip`n`nWould you like to open the Downloads folder?"
		IfMsgBox, Yes
			Run, % downloadsDir
	}
}
catch err
{
	; Catch and display any errors thrown by the library
	MsgBox, 16, Test Failed, % "Download failed!`n`nError: " . err.Message
}
