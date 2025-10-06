' ===================================================
'  Aegis Run_Aegis.vbs — Автозапуск и конфиг CodexLoop
' ===================================================

Option Explicit

Dim fso, shell, envPath, metaPath, envData, codexLoop
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

metaPath = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
envPath = "codex\config\build-config_Version2.env"
codexLoop = "codex\engine\CodexLoop.vbs"

WScript.Echo "[Aegis] Checking environment configuration..."

If Not fso.FileExists(metaPath) Then
    WScript.Echo "[ERROR] MetaEditor not found at: " & metaPath
    WScript.Quit(2)
End If

' === Ensure codex/config folder exists ===
If Not fso.FolderExists("codex") Then fso.CreateFolder("codex")
If Not fso.FolderExists("codex\config") Then fso.CreateFolder("codex\config")

' === Write .env configuration ===
Dim envText, t
envText = "METAEDITOR=" & metaPath & vbCrLf
envText = envText & "TARGET=codex\workspace\current.mq5" & vbCrLf
envText = envText & "OUTPUT=codex\build" & vbCrLf

Set t = fso.OpenTextFile(envPath, 2, True)
t.Write envText
t.Close

WScript.Echo "[Aegis] Environment file created: " & envPath
WScript.Echo "[Aegis] Launching CodexLoop..."

If fso.FileExists(codexLoop) Then
    shell.Run "cscript //nologo " & codexLoop, 1, True
Else
    WScript.Echo "[ERROR] CodexLoop.vbs not found at: " & codexLoop
    WScript.Quit(3)
End If

WScript.Echo "[Aegis] Done."
