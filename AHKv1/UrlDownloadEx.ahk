;================================================================================;
;	UrlDownloadEx - An AutoHotkey library for downloading files                  ;
;	Copyright (C) 2016-2026  Fooly Cooly https://github.com/Fooly-Cooly          ;
;	Licensed under the MIT License https://opensource.org/licenses/MIT           ;
;================================================================================;

class UrlDownloadExState {
	static guiHwnd := ""
	static progHwnd := ""
	static textHwnd := ""
	static start := 0
	static active := false
	static canceled := false
	static lastTick := 0
	static lastPct := -1
}

; 1. COM QueryInterface: Returns E_NOINTERFACE (0x80004002) and zeroes output pointer per COM rules
urlDownloadEx_QI(pThis, riid, ppvObject) {
	if (ppvObject)
		NumPut(0, ppvObject + 0, 0, "Ptr")
	return 0x80004002 ; E_NOINTERFACE
}

; Safe catch-all for passive COM methods (S_OK). Must be non-variadic for Fast callbacks in AHK v1.
urlDownloadEx_Stub(p1 := 0, p2 := 0, p3 := 0, p4 := 0, p5 := 0) {
	return 0
}

; 7. OnProgress Handler
urlDownloadEx_OnProgress(pThis, ulProgress, ulProgressMax, ulStatusCode, szStatusText) {
	if (!UrlDownloadExState.guiHwnd || UrlDownloadExState.canceled)
		return 0x80004004 ; E_ABORT

	; Ensure 32-bit unsigned interpretation
	ulProgress := ulProgress & 0xFFFFFFFF
	ulProgressMax := ulProgressMax & 0xFFFFFFFF

	now := A_TickCount
	if (ulProgressMax > 0) {
		pct := Floor(100 * ulProgress / ulProgressMax)

		; Throttle updates to avoid GUI lag on high-speed downloads
		if (pct != UrlDownloadExState.lastPct || now - UrlDownloadExState.lastTick > 60 || ulProgress == ulProgressMax) {
			UrlDownloadExState.lastPct := pct
			UrlDownloadExState.lastTick := now
			GuiControl,, % UrlDownloadExState.progHwnd, % pct

			txt := urlDownloadEx_FormatBytes(ulProgress) . " / " . urlDownloadEx_FormatBytes(ulProgressMax) . " (" . pct . "%)"
			if (pct >= 100)
				txt .= " - Done in " . Round((now - UrlDownloadExState.start) / 1000, 2) . "s"

			GuiControl,, % UrlDownloadExState.textHwnd, % txt
		}
	} else if (ulProgress > 0 && (now - UrlDownloadExState.lastTick > 100)) {
		; Unknown total size (e.g., chunked transfer encoding)
		UrlDownloadExState.lastTick := now
		GuiControl,, % UrlDownloadExState.textHwnd, % urlDownloadEx_FormatBytes(ulProgress) . " downloaded"
	}
	return 0
}

urlDownloadEx_FormatBytes(bytes) {
	if (bytes >= 1073741824)
		return Round(bytes / 1073741824, 2) . " GB"
	if (bytes >= 1048576)
		return Round(bytes / 1048576, 2) . " MB"
	if (bytes >= 1024)
		return Round(bytes / 1024, 1) . " KB"
	return bytes . " B"
}

urlDownloadEx_Cancel(CtrlHwnd := 0, GuiEvent := "", EventInfo := "") {
	UrlDownloadExState.canceled := true
	urlDownloadEx_Cleanup()
}

urlDownloadEx_Cleanup() {
	if (UrlDownloadExState.guiHwnd) {
		Gui, UrlDownloadExGui:Destroy
		UrlDownloadExState.guiHwnd := ""
	}
	UrlDownloadExState.progHwnd := ""
	UrlDownloadExState.textHwnd := ""
}

urlDownloadEx_WM_CLOSE(wParam, lParam, msg, hwnd) {
	if (hwnd == UrlDownloadExState.guiHwnd)
		urlDownloadEx_Cancel()
}

UrlDownloadEx(strUrl, strDest := ".", blnOver := true) {
	if (!strUrl || !RegExMatch(strUrl, "^https?://"))
		throw Exception("Invalid HTTP/HTTPS URL.", -1, strUrl)

	if (UrlDownloadExState.active)
		throw Exception("A download is already in progress.", -1)

	; Extract and sanitize target file name from URL (strip query parameters and anchors)
	cleanUrl := RegExReplace(strUrl, "[?#].*")
	SplitPath, cleanUrl, urlFileName
	urlFileName := RegExReplace(urlFileName, "[\\/:*?""<>|]")
	if (urlFileName == "")
		urlFileName := "download"

	; Resolve destination file path and ensure directory exists
	lastChar := SubStr(strDest, 0)
	if (strDest == "." || InStr(FileExist(strDest), "D") || lastChar == "\" || lastChar == "/") {
		destDir := RTrim(strDest, "\/")
		if (destDir == "" || destDir == ".")
			destDir := A_WorkingDir
		if (!InStr(FileExist(destDir), "D"))
			FileCreateDir, %destDir%
		strDest := destDir . "\" . urlFileName
	} else {
		SplitPath, strDest, , destDir
		if (destDir != "" && !InStr(FileExist(destDir), "D"))
			FileCreateDir, %destDir%
	}

	; Handle existing destination file
	if (FileExist(strDest)) {
		if (!blnOver)
			return false
		FileSetAttrib, -R, %strDest%
		FileDelete, %strDest%
	}

	; Clear WinINet URL cache to avoid stale responses
	DllCall("wininet\DeleteUrlCacheEntryW", "WStr", strUrl, "Int")

	; Reset state flags
	UrlDownloadExState.active := true
	UrlDownloadExState.canceled := false
	UrlDownloadExState.start := A_TickCount
	UrlDownloadExState.lastTick := 0
	UrlDownloadExState.lastPct := -1

	; Create GUI with proper non-overlapping layout
	Gui, UrlDownloadExGui:New, +HwndhGui +Border +ToolWindow -MaximizeBox -MinimizeBox -SysMenu
	UrlDownloadExState.guiHwnd := hGui
	Gui, UrlDownloadExGui:Color, White

	Gui, UrlDownloadExGui:Add, Button, w75 Section Default HwndhBtn gurlDownloadEx_Cancel, Cancel
	Gui, UrlDownloadExGui:Add, Progress, ys w360 Range0-100 -Smooth HwndhProg
	UrlDownloadExState.progHwnd := hProg
	Gui, UrlDownloadExGui:Add, Text, xp y+6 w360 HwndhText, Connecting...
	UrlDownloadExState.textHwnd := hText

	Gui, UrlDownloadExGui:Show,, Downloading...
	OnMessage(0x0010, "urlDownloadEx_WM_CLOSE")

	; Initialize COM IBindStatusCallback interface (cached statically for efficiency)
	static initialized := false, vtblBuffer, pInterface
	if (!initialized) {
		VarSetCapacity(vtblBuffer, A_PtrSize * 11, 0)
		cbQI := RegisterCallback("urlDownloadEx_QI", "Fast", 3)
		cbStub := RegisterCallback("urlDownloadEx_Stub", "Fast", 1)
		cbProg := RegisterCallback("urlDownloadEx_OnProgress", "Fast", 5)

		NumPut(cbQI, vtblBuffer, 0, "Ptr")
		Loop 5
			NumPut(cbStub, vtblBuffer, A_PtrSize * A_Index, "Ptr")
		NumPut(cbProg, vtblBuffer, A_PtrSize * 6, "Ptr")
		Loop 4
			NumPut(cbStub, vtblBuffer, A_PtrSize * (6 + A_Index), "Ptr")

		VarSetCapacity(pInterface, A_PtrSize, 0)
		NumPut(&vtblBuffer, pInterface, 0, "Ptr")
		initialized := true
	}

	hResult := 0
	try {
		hResult := DllCall("urlmon\URLDownloadToFileW"
			, "Ptr", 0
			, "WStr", strUrl
			, "WStr", strDest
			, "UInt", 0
			, "Ptr", &pInterface
			, "UInt")
	} finally {
		; Guaranteed cleanup of GUI, message monitor, and active state
		OnMessage(0x0010, "")
		urlDownloadEx_Cleanup()
		UrlDownloadExState.active := false
	}

	; If canceled by user, clean up any partial file and return false
	if (UrlDownloadExState.canceled || hResult == 0x80004004) {
		if (FileExist(strDest))
			FileDelete, %strDest%
		return false
	}

	; Download failed with error
	if (hResult != 0) {
		if (FileExist(strDest))
			FileDelete, %strDest%
		throw Exception(Format("URLDownloadToFile failed (HRESULT: 0x{:08X})", hResult & 0xFFFFFFFF), -1)
	}

	return FileExist(strDest) ? true : false
}

; Backward compatibility alias
urlDownload_File(strUrl, strDest := ".", blnOver := true) {
	return UrlDownloadEx(strUrl, strDest, blnOver)
}
