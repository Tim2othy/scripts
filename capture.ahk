#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
;  capture.ahk  -  quick-save highlighted text or a screenshot to Obsidian
; ----------------------------------------------------------------------------
;  Ctrl+F9   capture highlighted text  -> pick a category -> appended to file
;  Ctrl+F10  save a snip               -> snip first with Win+Shift+S, then this
;
;  Each entry is appended to captured\cap-<category>.md in a fixed shape that
;  is trivial to parse later (e.g. with Python / regex, for Anki):
;
;      ## 2026-06-20 14:32:05
;      <the text, or  ![[2026-06-20_14-32-05.png]]  for a screenshot>
;      <blank line>
;
;  Python:  re.split(r'(?m)^## ', text)  ->  each block = "timestamp\ncontent"
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

; ---------------- hotkeys ----------------
^F9:: {                  ; Ctrl+F9 — capture highlighted text
    global gMode, gText, catMenu
    saved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {            ; nothing was selected
        A_Clipboard := saved
        Notify("Nothing selected")
        return
    }
    gText := Trim(A_Clipboard, " `t`r`n")
    A_Clipboard := saved        ; leave the user's clipboard as it was
    gMode := "text"
    catMenu.Show()
}

^F10:: {                 ; Ctrl+F10 — save the snip sitting on the clipboard
    global gMode, catMenu
    gMode := "image"
    catMenu.Show()
}

; ---------------- core ----------------
OnCategory(itemName, itemPos, myMenu) {
    global gMode, gText, CapDir, ImgDir
    file    := CapDir "\cap-" itemName ".md"
    heading := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    if (gMode = "text") {
        FileAppend("## " heading "`r`n" gText "`r`n`r`n", file, "UTF-8")
        Notify("Saved to " itemName)
    } else if (gMode = "image") {
        stamp   := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
        imgPath := ImgDir "\" stamp ".png"
        if SaveClipImage(imgPath) {
            FileAppend("## " heading "`r`n![[" stamp ".png]]`r`n`r`n", file, "UTF-8")
            Notify("Saved image to " itemName)
        } else {
            Notify("No image on clipboard — snip with Win+Shift+S first")
        }
    }
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
