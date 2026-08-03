# UrlDownload

A robust, crash-resilient AutoHotkey library for downloading files using Windows native `urlmon.dll` and `IBindStatusCallback` COM interfaces.

Unlike the built-in `UrlDownloadToFile` command, this library provides a real-time progress GUI, accurate byte transfer tracking, cache clearing to prevent stale downloads, and full memory safety on both x86 and x64 architectures.

---

## Features

* **Dual Compatibility:** Dedicated, fully optimized versions for both **AutoHotkey v2** and **AutoHotkey v1.1**.
* **Real-time Download GUI:** Displays a sleek progress bar, byte counts, and completion time.
* **COM & Memory Safe:** Precision VTable structure built specifically to protect stack integrity and prevent access violation crashes during C++ callback execution.
* **Cache Management:** Automatically clears the WinINet URL cache prior to downloading to avoid stale or corrupted file issues.
* **Path Smart:** Automatically resolves directory paths and extracts filenames from target URLs.

---

## Repository Structure

| File | Description |
| --- | --- |
| `UrlDownload.ahkv1.ahk` | Production-ready library for **AHK v1.1** |
| `UrlDownload.ahkv2.ahk` | Production-ready library for **AHK v2** |
| `Test_UrlDownload.ahkv1.ahk` | Interactive test script for **AHK v1.1** |
| `Test_UrlDownload.ahkv2.ahk` | Interactive test script for **AHK v2** |
| `LICENSE` | Full GPLv3 License text |

---

## Quick Start & Usage

### AutoHotkey v2 Example

```autohotkey
#Include UrlDownload.ahkv2.ahk

; Download a file to a specific path
try {
    success := urlDownload_File("https://download.thinkbroadband.com/5MB.zip", A_ScriptDir . "\5MB.zip", true)
    if (success)
        MsgBox("Download complete!", "Success", "64")
} catch Error as err {
    MsgBox("Download failed: " . err.Message, "Error", "16")
}

```

### AutoHotkey v1 Example

```autohotkey
#Include UrlDownload.ahk

; Download a file to a target folder
try {
    success := urlDownload_File("https://download.thinkbroadband.com/5MB.zip", A_Desktop, true)
    if (success)
        MsgBox, 64, Success, Download complete!
} catch err {
    MsgBox, 16, Error, % "Download failed: " . err.Message
}

```

---

## Function Reference

```autohotkey
urlDownload_File(strUrl, strDest := ".", blnOver := true)

```

### Parameters

* **`strUrl`** *(String, Required)*: The `http://` or `https://` URL of the file to download.
* **`strDest`** *(String, Optional)*: The destination file path or directory.
* If set to `"."` (default) or a directory path, the file name is automatically extracted from the URL and saved into that directory.


* **`blnOver`** *(Boolean, Optional)*: Whether to overwrite the destination file if it already exists. Default is `true`.

### Return Value

Returns `true` if the file exists at the destination upon completion, or `false` if skipped due to overwrite settings. Throws an exception if the download or system call fails.

---

## Running the Tests

To verify functionality on your machine, simply run the included test script for your AutoHotkey version:

* **AHK v2:** Run `Test_UrlDownload.ahkv2.ahk`
* **AHK v1:** Run `Test_UrlDownload.ahkv1.ahk`

The test scripts will prompt you and download a 5MB test file directly to your user `Downloads` folder while showing the real-time progress GUI.

---

## License

This software is licensed under the terms of the **GNU General Public License v3.0 (GPLv3)**. See the `LICENSE` file for details.