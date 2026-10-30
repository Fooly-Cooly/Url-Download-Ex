;================================================================================;
;	UrlDownloadEx - An AutoHotkey library for downloading files                  ;
;	Copyright (C) 2016-2026  Fooly Cooly https://github.com/Fooly-Cooly          ;
;	Licensed under the MIT License https://opensource.org/licenses/MIT           ;
;================================================================================;

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#Include UrlDownloadEx.ahk

; 1. Define a reliable test download URL
testUrl := "https://download.thinkbroadband.com/5MB.zip"

; 2. Resolve the current user's Downloads folder
EnvGet, userProfile, USERPROFILE
downloadsDir := userProfile . "\Downloads"

try 
{
	; Prompt the user
	MsgBox, 64, UrlDownloadEx Test, % "Click OK to start downloading the test file to your Downloads folder:`n`n" . downloadsDir

	; 3. Run the download
	; Parameters: strUrl, strDest, blnOver
	success := UrlDownloadEx(testUrl, downloadsDir, true)

	if (success)
	{
		MsgBox, 36, Success, % "Download complete!`n`nSaved to: " . downloadsDir . "\5MB.zip`n`nWould you like to open the Downloads folder?"
		IfMsgBox, Yes
			Run, % downloadsDir
	}
	else
	{
		MsgBox, 48, UrlDownloadEx Test, Download was canceled or skipped.
	}
}
catch err
{
	; Catch and display any errors thrown by the library
	MsgBox, 16, Test Failed, % "Download failed!`n`nError: " . err.Message
}

ExitApp
