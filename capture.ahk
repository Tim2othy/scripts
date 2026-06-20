#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
;  capture.ahk  -  quick-save highlighted text OR a screenshot to Obsidian
; ----------------------------------------------------------------------------
;  Ctrl+F9   one hotkey for both:
;              - if text is highlighted, it captures that text
;              - otherwise it saves the screenshot on the clipboard
;                (snip first with Win+Shift+S)
;            then a tiny menu asks for a category and appends the entry.
;
;  Each entry is one line in captured\cap-<category>.md, as a numbered-list
;  item (Obsidian auto-renumbers 1, 2, 3, ...):
;
;      1. 2026-06-20 21:19:34 - the captured text
;      1. 2026-06-20 21:20:02 - ![[2026-06-20_21-20-02.png]]
;
;  Python:  for each line  ->  re.match(r'^\d+\. (.+?) - (.*)$', line)
;           group(1) = timestamp, group(2) = text or image embed.
; ============================================================================

; ---------------- config ----------------
CapDir     := "C:\Users\timtj\GitHub\My-Obsidian\captured"
ImgDir     := CapDir "\images"
Categories := ["advice", "interesting", "other"]
; ----------------------------------------

DirCreate(ImgDir)        ; creates captured\ and captured\images if missing

global gMode := ""       ; "text" or "image" — what the menu should save
global gText := ""       ; the captured text, when gMode = "text"

; build the category popup once; it shows at the cursor, Esc/click-away cancels
global catMenu := Menu()
for cat in Categories
    catMenu.Add(cat, OnCategory)

; ---------------- hotkey ----------------
^F9:: {                  ; Ctrl+F9 — capture text if selected, else the screenshot
    global gMode, gText, catMenu
    saved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    if (ClipWait(0.5) && A_Clipboard != "") {        ; something was highlighted
        gText := RegExReplace(Trim(A_Clipboard), "\s+", " ")   ; flatten to one line
        A_Clipboard := saved                          ; leave clipboard untouched
        gMode := "text"
        catMenu.Show()
        return
    }
    A_Clipboard := saved                              ; nothing selected -> restore
    if ClipHasImage() {
        gMode := "image"
        catMenu.Show()
    } else {
        Notify("Nothing highlighted, and no screenshot on the clipboard")
    }
}

; ---------------- core ----------------
OnCategory(itemName, itemPos, myMenu) {
    global gMode, gText, CapDir, ImgDir
    file    := CapDir "\cap-" itemName ".md"
    heading := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    if (gMode = "text") {
        FileAppend("1. " heading " - " gText "`r`n", file, "UTF-8")
        Notify("Saved to " itemName)
    } else if (gMode = "image") {
        stamp   := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
        imgPath := ImgDir "\" stamp ".png"
        if SaveClipImage(imgPath) {
            FileAppend("1. " heading " - ![[" stamp ".png]]`r`n", file, "UTF-8")
            Notify("Saved image to " itemName)
        } else {
            Notify("Couldn't read an image from the clipboard")
        }
    }
}

; True if the clipboard holds a bitmap (CF_BITMAP=2 or CF_DIB=8).
ClipHasImage() {
    return DllCall("IsClipboardFormatAvailable", "UInt", 2)
        || DllCall("IsClipboardFormatAvailable", "UInt", 8)
}

; Save the clipboard image to PNG via a short-lived PowerShell call.
; Keeps this script dependency-free (no GDI+ library) and nothing stays resident.
SaveClipImage(path) {
    psCmd := "Add-Type -AssemblyName System.Windows.Forms,System.Drawing; "
           . "$i=[System.Windows.Forms.Clipboard]::GetImage(); "
           . "if($i){$i.Save('" path "',[System.Drawing.Imaging.ImageFormat]::Png)}"
    RunWait("powershell.exe -NoProfile -Sta -WindowStyle Hidden -Command "
            . Chr(34) . psCmd . Chr(34), , "Hide")
    return FileExist(path) != ""
}

; Brief confirmation tooltip that clears itself.
Notify(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1200)
}
