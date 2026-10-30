;================================================================================;
;	UrlDownloadEx - An AutoHotkey library for downloading files                  ;
;	Copyright (C) 2016-2026  Fooly Cooly https://github.com/Fooly-Cooly          ;
;	Licensed under the MIT License https://opensource.org/licenses/MIT           ;
;================================================================================;

#Requires AutoHotkey v2.0
#Include "UrlDownloadEx.ahk"

; 1. Define a reliable test download URL
testUrl := "https://download.thinkbroadband.com/5MB.zip"

; 2. Resolve the current user's Downloads folder
downloadsDir := EnvGet("USERPROFILE") . "\Downloads"

try 
{
	; Prompt the user
	MsgBox("Click OK to start downloading the test file to your Downloads folder:`n`n" . downloadsDir, "UrlDownloadEx Test", "64")

	; 3. Run the download
	; Parameters: strUrl, strDest, blnOver
	success := UrlDownloadEx(testUrl, downloadsDir, true)

	if success
	{
		result := MsgBox("Download complete!`n`nSaved to: " . downloadsDir . "\5MB.zip`n`nWould you like to open the Downloads folder?", "Success", "36")
		if (result == "Yes")
			Run(downloadsDir)
	}
	else
	{
		MsgBox("Download was canceled or skipped.", "UrlDownloadEx Test", "48")
	}
}
catch Error as err
{
	; Catch and display any errors thrown by the library
	MsgBox("Download failed!`n`nError: " . err.Message, "Test Failed", "16")
}

ExitApp()
