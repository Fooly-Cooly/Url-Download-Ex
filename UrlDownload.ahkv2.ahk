;================================================================================;
;	UrlDownload - An AutoHotkey v2 library for downloading files                 ;
;	Copyright (C) 2016  Fooly Cooly https://github.com/Fooly-Cooly               ;
;	Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt                ;
;================================================================================;

class UrlDownloadState {
	static gui := "", prog := "", text := "", start := 0
}

; Safe, catch-all stubs using variadic arguments (p*)
urlDownload_QI(p*) => 0x80004002 ; 1. QueryInterface (E_NOINTERFACE)
urlDownload_Stub(p*) => 0        ; Safe catch-all for passive COM methods (S_OK)

; 7. OnProgress Handler
urlDownload_OnProgress(pThis, ulProgress, ulProgressMax, ulStatusCode, szStatusText) {
	if !UrlDownloadState.gui
		return 0x80004004 ; E_ABORT

	if (ulProgressMax > 0) {
		pct := Integer(100 * ulProgress / ulProgressMax)
		UrlDownloadState.prog.Value := pct
		
		txt := Format("{1} / {2} Bytes", ulProgress, ulProgressMax)
		if (pct >= 100)
			txt .= Format(" (Done in {1:.2f}s)", (A_TickCount - UrlDownloadState.start) / 1000)
			
		UrlDownloadState.text.Value := txt
	}
	return 0
}

urlDownload_File(strUrl, strDest := ".", blnOver := true) {
	if !strUrl || !RegExMatch(strUrl, "^https?://")
		throw ValueError("Invalid HTTP/HTTPS URL.", -1, strUrl)

	SplitPath(strUrl, &strFile)
	strDest := ((strDest == ".") || DirExist(strDest)) ? RTrim(strDest, "\") . "\" . (strFile || "download") : strDest

	if FileExist(strDest) {
		if !blnOver
			return false
		FileDelete(strDest)
	}

	DllCall("wininet\DeleteUrlCacheEntryW", "Str", strUrl, "Int")

	UrlDownloadState.start := A_TickCount
	UrlDownloadState.gui := Gui("+Border +ToolWindow -MaximizeBox -MinimizeBox -SysMenu", "Downloading...")
	UrlDownloadState.gui.BackColor := "White"
	
	btn := UrlDownloadState.gui.Add("Button", "Default", "Cancel")
	UrlDownloadState.prog := UrlDownloadState.gui.Add("Progress", "Xp+50 Yp W" . (A_ScreenWidth // 4) . " Range0-100")
	UrlDownloadState.text := UrlDownloadState.gui.Add("Text", "Xp Yp+25 W" . (A_ScreenWidth // 4), "Connecting...")
	
	cleanup := (*) => (IsObject(UrlDownloadState.gui) && (UrlDownloadState.gui.Destroy(), UrlDownloadState.gui := ""))
	btn.OnEvent("Click", cleanup)
	UrlDownloadState.gui.OnEvent("Close", cleanup)
	UrlDownloadState.gui.Show()

	; IBindStatusCallback Param Counts
	paramCounts := [3, 1, 1, 3, 2, 2, 5, 3, 3, 5, 3]
	vtblBuffer := Buffer(A_PtrSize * 11, 0)
	cbList := []

	; Dynamically assign callbacks based on method index
	for idx, count in paramCounts {
		func := (idx == 1) ? urlDownload_QI : (idx == 7) ? urlDownload_OnProgress : urlDownload_Stub
		cb := CallbackCreate(func, "Fast", count)
		cbList.Push(cb)
		NumPut("Ptr", cb, vtblBuffer, A_PtrSize * (idx - 1))
	}

	pInterface := Buffer(A_PtrSize)
	NumPut("Ptr", vtblBuffer.Ptr, pInterface)

	hResult := DllCall("urlmon\URLDownloadToFile", "Ptr", 0, "Str", strUrl, "Str", strDest, "UInt", 0, "Ptr", pInterface.Ptr, "HRESULT")

	cleanup()
	for cb in cbList
		CallbackFree(cb)

	if hResult
		throw Error(Format("URLDownloadToFile failed (HRESULT: 0x{1:X})", hResult & 0xFFFFFFFF), -1)

	return FileExist(strDest) ? true : false
}
