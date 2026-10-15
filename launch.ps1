param([string]$GodotPath = $env:GODOT_PATH)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $candidates = @('D:\Godot\Godot_v4.7.2-stable_win64.exe', 'godot', 'godot4')
    foreach ($candidate in $candidates) {
        $resolved = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($resolved) { $GodotPath = $resolved.Source; break }
    }
}
if (-not $GodotPath) { throw 'Pass -GodotPath with your Godot 4.7.2 executable, or import project.godot in Godot.' }
Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $PSScriptRoot + '"')) -WindowStyle Hidden
