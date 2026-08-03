#Requires AutoHotkey v2.0
#Include "UrlDownload.ahkv2.ahk"

; 1. Define a reliable test download URL
testUrl := "http://ipv4.download.thinkbroadband.com/5MB.zip"

; 2. Resolve the current user's Downloads folder
downloadsDir := EnvGet("USERPROFILE") . "\Downloads"

try 
{
	; Prompt the user
	MsgBox("Click OK to start downloading the test file to your Downloads folder:`n`n" . downloadsDir, "UrlDownload Test", "64")

	; 3. Run the download
	; Parameters: strUrl, strDest, blnOver
	success := urlDownload_File(testUrl, downloadsDir, true)

	if success
	{
		result := MsgBox("Download complete!`n`nSaved to: " . downloadsDir . "\1MB.zip`n`nWould you like to open the Downloads folder?", "Success", "36")
		if (result == "Yes")
			Run(downloadsDir)
	}
}
catch Error as err
{
	; Catch and display any errors thrown by the library
	MsgBox("Download failed!`n`nError: " . err.Message, "Test Failed", "16")
}
