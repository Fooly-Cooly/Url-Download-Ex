;================================================================================;
;	UrlDownloadEx - An AutoHotkey library for downloading files                  ;
;	Copyright (C) 2016-2026  Fooly Cooly https://github.com/Fooly-Cooly          ;
;	Licensed under the MIT License https://opensource.org/licenses/MIT           ;
;================================================================================;

class UrlDownloadExState {
	static gui := ""
	static prog := ""
	static text := ""
	static start := 0
	static active := false
	static canceled := false
	static lastTick := 0
	static lastPct := -1
}

; 1. COM QueryInterface: Returns E_NOINTERFACE (0x80004002) and zeroes output pointer per COM rules
urlDownloadEx_QI(pThis, riid, ppvObject) {
	if ppvObject
		NumPut("Ptr", 0, ppvObject)
	return 0x80004002 ; E_NOINTERFACE
}

; Safe catch-all for passive COM methods (S_OK)
urlDownloadEx_Stub(p*) => 0

; 7. OnProgress Handler
urlDownloadEx_OnProgress(pThis, ulProgress, ulProgressMax, ulStatusCode, szStatusText) {
	if (!UrlDownloadExState.gui || UrlDownloadExState.canceled)
		return 0x80004004 ; E_ABORT

	; Ensure 32-bit unsigned interpretation
	ulProgress := ulProgress & 0xFFFFFFFF
	ulProgressMax := ulProgressMax & 0xFFFFFFFF

	now := A_TickCount
	if (ulProgressMax > 0) {
		pct := Integer(100 * ulProgress / ulProgressMax)

		; Throttle updates to avoid GUI lag on high-speed downloads
		if (pct != UrlDownloadExState.lastPct || now - UrlDownloadExState.lastTick > 60 || ulProgress == ulProgressMax) {
			UrlDownloadExState.lastPct := pct
			UrlDownloadExState.lastTick := now
			UrlDownloadExState.prog.Value := pct

			txt := urlDownloadEx_FormatBytes(ulProgress) . " / " . urlDownloadEx_FormatBytes(ulProgressMax) . " (" . pct . "%)"
			if (pct >= 100)
				txt .= Format(" - Done in {1:.2f}s", (now - UrlDownloadExState.start) / 1000)

			UrlDownloadExState.text.Value := txt
		}
	} else if (ulProgress > 0 && (now - UrlDownloadExState.lastTick > 100)) {
		; Unknown total size (e.g., chunked transfer encoding)
		UrlDownloadExState.lastTick := now
		UrlDownloadExState.text.Value := urlDownloadEx_FormatBytes(ulProgress) . " downloaded"
	}
	return 0
}

urlDownloadEx_FormatBytes(bytes) {
	if (bytes >= 1073741824)
		return Format("{1:.2f} GB", bytes / 1073741824)
	if (bytes >= 1048576)
		return Format("{1:.2f} MB", bytes / 1048576)
	if (bytes >= 1024)
		return Format("{1:.1f} KB", bytes / 1024)
	return bytes . " B"
}

UrlDownloadEx(strUrl, strDest := ".", blnOver := true) {
	if !strUrl || !RegExMatch(strUrl, "^https?://")
		throw ValueError("Invalid HTTP/HTTPS URL.", -1, strUrl)

	if UrlDownloadExState.active
		throw Error("A download is already in progress.", -1)

	; Extract and sanitize target file name from URL (strip query parameters and anchors)
	cleanUrl := RegExReplace(strUrl, "[?#].*")
	SplitPath(cleanUrl, &urlFileName)
	urlFileName := RegExReplace(urlFileName, '[\\/:*?"<>|]')
	if (urlFileName == "")
		urlFileName := "download"

	; Resolve destination file path and ensure directory exists
	if (strDest == "." || DirExist(strDest) || SubStr(strDest, -1) == "\" || SubStr(strDest, -1) == "/") {
		destDir := RTrim(strDest, "\/")
		if (destDir == "" || destDir == ".")
			destDir := A_WorkingDir
		if !DirExist(destDir)
			DirCreate(destDir)
		strDest := destDir . "\" . urlFileName
	} else {
		SplitPath(strDest, , &destDir)
		if (destDir != "" && !DirExist(destDir))
			DirCreate(destDir)
	}

	; Handle existing destination file
	if FileExist(strDest) {
		if !blnOver
			return false
		try FileSetAttrib("-R", strDest)
		FileDelete(strDest)
	}

	; Clear WinINet URL cache to avoid stale responses
	DllCall("wininet\DeleteUrlCacheEntryW", "Str", strUrl, "Int")

	; Reset state flags
	UrlDownloadExState.active := true
	UrlDownloadExState.canceled := false
	UrlDownloadExState.start := A_TickCount
	UrlDownloadExState.lastTick := 0
	UrlDownloadExState.lastPct := -1

	; Create GUI with proper non-overlapping layout
	UrlDownloadExState.gui := Gui("+Border +ToolWindow -MaximizeBox -MinimizeBox -SysMenu", "Downloading...")
	UrlDownloadExState.gui.BackColor := "White"

	btn := UrlDownloadExState.gui.Add("Button", "w75 Section Default", "Cancel")
	UrlDownloadExState.prog := UrlDownloadExState.gui.Add("Progress", "ys w360 Range0-100 -Smooth")
	UrlDownloadExState.text := UrlDownloadExState.gui.Add("Text", "xp y+6 w360", "Connecting...")

	onCancel(*) {
		UrlDownloadExState.canceled := true
		if IsObject(UrlDownloadExState.gui) {
			UrlDownloadExState.gui.Destroy()
			UrlDownloadExState.gui := ""
		}
	}
	btn.OnEvent("Click", onCancel)
	UrlDownloadExState.gui.OnEvent("Close", onCancel)
	UrlDownloadExState.gui.Show()

	; Initialize COM IBindStatusCallback interface (cached statically for efficiency)
	static vtblBuffer := "", pInterface := ""
	if !pInterface {
		paramCounts := [3, 1, 1, 3, 2, 2, 5, 3, 3, 5, 3]
		vtblBuffer := Buffer(A_PtrSize * 11, 0)
		for idx, count in paramCounts {
			func := (idx == 1) ? urlDownloadEx_QI : (idx == 7) ? urlDownloadEx_OnProgress : urlDownloadEx_Stub
			cb := CallbackCreate(func, , count)
			NumPut("Ptr", cb, vtblBuffer, A_PtrSize * (idx - 1))
		}
		pInterface := Buffer(A_PtrSize, 0)
		NumPut("Ptr", vtblBuffer.Ptr, pInterface)
	}

	hResult := 0
	try {
		hResult := DllCall("urlmon\URLDownloadToFileW"
			, "Ptr", 0
			, "Str", strUrl
			, "Str", strDest
			, "UInt", 0
			, "Ptr", pInterface.Ptr
			, "HRESULT")
	} finally {
		; Guaranteed cleanup of GUI and active state
		if IsObject(UrlDownloadExState.gui) {
			UrlDownloadExState.gui.Destroy()
			UrlDownloadExState.gui := ""
		}
		UrlDownloadExState.prog := ""
		UrlDownloadExState.text := ""
		UrlDownloadExState.active := false
	}

	; If canceled by user, clean up any partial file and return false
	if (UrlDownloadExState.canceled || hResult == 0x80004004) {
		if FileExist(strDest)
			try FileDelete(strDest)
		return false
	}

	; Download failed with error
	if (hResult != 0) {
		if FileExist(strDest)
			try FileDelete(strDest)
		throw Error(Format("URLDownloadToFile failed (HRESULT: 0x{1:08X})", hResult & 0xFFFFFFFF), -1)
	}

	return FileExist(strDest) ? true : false
}

; Backward compatibility alias
urlDownload_File(strUrl, strDest := ".", blnOver := true) => UrlDownloadEx(strUrl, strDest, blnOver)
