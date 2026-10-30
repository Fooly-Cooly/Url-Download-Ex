<div align="center">

# UrlDownloadEx

**A robust, crash-resilient AutoHotkey library for downloading files with real-time GUI progress tracking, cache management, and native COM integration.**

[![AutoHotkey v1](https://img.shields.io/badge/AutoHotkey-v1.1-334455.svg?logo=autohotkey)](https://www.autohotkey.com/)
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0-337744.svg?logo=autohotkey)](https://www.autohotkey.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6.svg?logo=windows)](https://www.microsoft.com/)
[![Architecture](https://img.shields.io/badge/Architecture-x86%20%7C%20x64-informational.svg)]()

</div>

---

## Overview

In standard AutoHotkey, the built-in `UrlDownloadToFile` command is a "black box": it freezes or runs invisibly without user feedback, provides no transfer metrics, cannot easily be canceled by the user, and frequently serves stale files from the WinINet URL cache.

**`UrlDownloadEx`** replaces this with a production-grade wrapper around the native Windows `urlmon.dll` API and `IBindStatusCallback` COM interface. It delivers real-time download visual feedback, precise byte counters, automatic cache clearing, directory creation guards, and guaranteed stack memory safety across both 32-bit and 64-bit Windows.

---

## Why Use `UrlDownloadEx`?

| Feature | Built-in `UrlDownloadToFile` | `UrlDownloadEx` Library |
| :--- | :---: | :---: |
| **Visual Feedback** | ❌ None (silent / blind) |  Sleek real-time progress bar & transfer metrics |
| **User Cancellation** | ❌ Cannot be aborted |  Responsive Cancel button with clean abort |
| **Cache Management** | ⚠️ Can return stale/cached files |  Purges WinINet cache prior to downloading |
| **Path Safety** | ❌ Fails if target folder is missing |  Auto-creates missing parent directories |
| **Sanitization** | ❌ Fails on URLs with query parameters |  Strips query strings & sanitizes filenames |
| **Corrupted File Cleanup**| ⚠️ Leaves partial files on failure |  Deletes partial/broken files on error or cancel |
| **Read-Only Overwriting** | ❌ Fails if target is marked Read-Only |  Clears `-R` attribute before overwriting |
| **Architecture Safety** | N/A |  COM VTable memory-safe on x86 and x64 |
| **Dual Compatibility** | Varies by syntax |  Dedicated implementations for **AHK v1** & **v2** |

---

## Repository Structure

```text
Url-Download-Ex/
├── AHKv1/
│   ├── UrlDownloadEx.ahk        # Production library for AutoHotkey v1.1
│   └── UrlDownloadEx_Test.ahk   # Interactive test suite for AutoHotkey v1.1
├── AHKv2/
│   ├── UrlDownloadEx.ahk        # Production library for AutoHotkey v2.0
│   └── UrlDownloadEx_Test.ahk   # Interactive test suite for AutoHotkey v2.0
├── LICENSE                      # Full MIT License text
└── README.md                    # Documentation
```

---

## Quick Start & Usage

### AutoHotkey v2

```autohotkey
#Requires AutoHotkey v2.0
#Include "AHKv2/UrlDownloadEx.ahk" ; Or place UrlDownloadEx.ahk in your Lib/ folder

targetUrl := "https://download.thinkbroadband.com/5MB.zip"
savePath  := A_ScriptDir . "\5MB.zip"

try {
    ; Download with overwrite enabled
    if UrlDownloadEx(targetUrl, savePath, true)
        MsgBox("Download complete!", "Success", "64")
    else
        MsgBox("Download was canceled.", "Canceled", "48")
} catch Error as err {
    MsgBox("Download failed: " . err.Message, "Error", "16")
}
```

### AutoHotkey v1.1

```autohotkey
#NoEnv
SetWorkingDir %A_ScriptDir%
#Include AHKv1\UrlDownloadEx.ahk ; Or place UrlDownloadEx.ahk in your Lib\ folder

targetUrl := "https://download.thinkbroadband.com/5MB.zip"
saveFolder := A_Desktop

try {
    ; When passing a folder, the filename is extracted automatically from the URL
    if UrlDownloadEx(targetUrl, saveFolder, true)
        MsgBox, 64, Success, Download complete!
    else
        MsgBox, 48, Canceled, Download was canceled.
} catch err {
    MsgBox, 16, Error, % "Download failed: " . err.Message
}
```

---

## API Reference

```autohotkey
UrlDownloadEx(strUrl, strDest := ".", blnOver := true)
```

> **Backward Compatibility:** `urlDownload_File(strUrl, strDest, blnOver)` is fully supported as an alias.

### Parameters

* **`strUrl`** `(String, Required)`  
  The direct `http://` or `https://` web address of the file to download.
  * *Note:* URL query strings (e.g. `?auth=token`) and anchors (`#hash`) are automatically parsed and stripped when resolving file names.

* **`strDest`** `(String, Optional)`  
  The target file path or directory. Default is `"."` (current working directory).
  * **File Path:** If a full path with filename is supplied (e.g. `C:\Downloads\file.zip`), the file is saved directly to that path. If the parent folder doesn't exist, it is created automatically.
  * **Directory Path:** If set to `"."`, an existing directory, or a path ending in `\` or `/`, the target filename is automatically extracted from `strUrl` and saved into that directory.

* **`blnOver`** `(Boolean, Optional)`  
  Whether to overwrite the destination file if it already exists. Default is `true`.
  * If `false` and the destination file exists, the function skips the download and returns `false`.
  * If `true` and the destination file is marked Read-Only, the attribute is removed automatically before deletion.

### Return Values

* **`true`** — The file was downloaded successfully and verified to exist at `strDest`.
* **`false`** — The download was either canceled by the user (clicking "Cancel" / closing window) or skipped because `blnOver := false` and the destination already existed.
* **Throws Exception** — If the network request fails (e.g., 404 Not Found, DNS failure, connection timeout, invalid URL scheme).

---

## Technical Highlights

* **Precision COM VTable Integration:**  
  Constructs a compliant 11-method `IBindStatusCallback` interface matching Windows SDK specifications. Every method signature is explicitly typed to prevent stack pointer desynchronization during native Windows callbacks.
* **Cached Memory Footprint:**  
  The COM VTable and thunks are registered and cached statically. Rapid batch downloads incur zero callback re-allocation overhead and zero memory leaks.
* **Smooth, Throttled UI Updates:**  
  Progress updates are rendered via a high-performance throttle (~16 updates/sec max or on percent change). This prevents CPU spikes and window stutter on high-speed gigabit downloads.
* **Auto-Execute Section Safe:**  
  Designed strictly for seamless `#Include` embedding in existing projects without terminating the host script's auto-execute flow.

---

## Running the Interactive Tests

Both versions include a turnkey test script that verifies network connectivity, UI rendering, and file integrity against a public 5MB test file:

* **AutoHotkey v2:** Run [`AHKv2/UrlDownloadEx_Test.ahk`](AHKv2/UrlDownloadEx_Test.ahk)
* **AutoHotkey v1:** Run [`AHKv1/UrlDownloadEx_Test.ahk`](AHKv1/UrlDownloadEx_Test.ahk)

---

## License

This project is licensed under the **[MIT License](LICENSE)** — free for both personal and commercial use in open-source or proprietary scripts.
