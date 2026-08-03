;================================================================================;
;	UrlDownload - An AutoHotkey v1 library for downloading files                 ;
;	Copyright (C) 2016  Fooly Cooly https://github.com/Fooly-Cooly               ;
;	Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt                ;
;================================================================================;

; Encapsulate state to avoid global variable conflicts
class UrlDownloadState {
	static guiHwnd := ""
	static progHwnd := ""
	static textHwnd := ""
	static start := 0
}

; Safe variadic (p*) stubs for COM compatibility
urlDownload_QI(p*) {
	return 0x80004002 ; 1. QueryInterface (E_NOINTERFACE)
}

urlDownload_Stub(p*) {
	return 0 ; Safe catch-all for passive COM methods (S_OK)
}

; OnProgress Handler
urlDownload_OnProgress(pThis, ulProgress, ulProgressMax, ulStatusCode, szStatusText) {
	if (!UrlDownloadState.guiHwnd)
		return 0x80004004 ; E_ABORT

	if (ulProgressMax > 0) {
		pct := Floor(100 * ulProgress / ulProgressMax)
		
		; Update GUI controls using their HWND handles
		GuiControl,, % UrlDownloadState.progHwnd, % pct
		
		txt := ulProgress . " / " . ulProgressMax . " Bytes"
		if (pct >= 100)
			txt .= " (Done in " . Round((A_TickCount - UrlDownloadState.start) / 1000, 2) . "s)"
			
		GuiControl,, % UrlDownloadState.textHwnd, % txt
	}
	return 0
}

; GUI Cleanup Handler
urlDownload_Cancel() {
	Gui, UrlDownloadGui:Destroy
	UrlDownloadState.guiHwnd := ""
}

urlDownload_File(strUrl, strDest := ".", blnOver := true) {
	if (!strUrl || !RegExMatch(strUrl, "^https?://"))
		throw Exception("Invalid HTTP/HTTPS URL.", -1, strUrl)

	SplitPath, strUrl, strFile
	if (strDest == "." || InStr(FileExist(strDest), "D"))
		strDest := RTrim(strDest, "\") . "\" . (strFile ? strFile : "download")

	if (FileExist(strDest)) {
		if (!blnOver)
			return false
		FileDelete, %strDest%
	}

	; Clear WinINet URL Cache (using WStr for ANSI/Unicode safety)
	DllCall("wininet\DeleteUrlCacheEntryW", "WStr", strUrl, "Int")

	; Initialize GUI
	UrlDownloadState.start := A_TickCount
	Gui, UrlDownloadGui:New, +HwndhGui +Border +ToolWindow -MaximizeBox -MinimizeBox -SysMenu
	UrlDownloadState.guiHwnd := hGui
	Gui, UrlDownloadGui:Color, White
	
	Gui, UrlDownloadGui:Add, Button, Default HwndhBtn gurlDownload_Cancel, Cancel
	Gui, UrlDownloadGui:Add, Progress, % "Xp+50 Yp W" . (A_ScreenWidth // 4) . " Range0-100 HwndhProg"
	UrlDownloadState.progHwnd := hProg
	Gui, UrlDownloadGui:Add, Text, % "Xp Yp+25 W" . (A_ScreenWidth // 4) . " HwndhText", Connecting...
	UrlDownloadState.textHwnd := hText
	
	Gui, UrlDownloadGui:Show,, Downloading...

	; VTable Setup
	paramCounts := [3, 1, 1, 3, 2, 2, 5, 3, 3, 5, 3]
	VarSetCapacity(vtblBuffer, A_PtrSize * 11, 0)
	cbList := []

	for idx, count in paramCounts {
		funcName := (idx == 1) ? "urlDownload_QI" : (idx == 7) ? "urlDownload_OnProgress" : "urlDownload_Stub"
		cb := RegisterCallback(funcName, "Fast", count)
		cbList.Push(cb)
		NumPut(cb, vtblBuffer, A_PtrSize * (idx - 1), "Ptr")
	}

	VarSetCapacity(pInterface, A_PtrSize, 0)
	NumPut(&vtblBuffer, pInterface, 0, "Ptr")

	; Execute Native Download
	hResult := DllCall("urlmon\URLDownloadToFileW"
		, "Ptr", 0
		, "WStr", strUrl
		, "WStr", strDest
		, "UInt", 0
		, "Ptr", &pInterface
		, "UInt")

	; Clean up GUI and Memory
	urlDownload_Cancel()
	for _, cb in cbList
		DllCall("GlobalFree", "Ptr", cb, "Ptr")

	; Evaluate success
	if (hResult)
		throw Exception(Format("URLDownloadToFile failed (HRESULT: 0x{:X})", hResult & 0xFFFFFFFF), -1)

	return FileExist(strDest) ? true : false
}
