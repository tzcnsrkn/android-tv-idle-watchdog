<#
.SYNOPSIS
    Monitors a Xiaomi Mi Stick for *active media playback* and sends a Sleep command if idle.
#>

# --- CONFIGURATION ---
$MiStickIP = "192.168.55.6"       
$AdbPath = "C:\adb\adb.exe"       
$IdleLimitMinutes = 5            # Changed to 15 (1 minute is too short for testing)
$CheckInterval = 60               # Check every 60 seconds
$LogFile = "C:\adb\mistick_log.txt" # Define a log file

# --- HELPER FUNCTION ---
function Log-Message {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogLine
}

# --- LOGIC ---
$IdleCounter = 0
Log-Message "Starting Watchdog for $MiStickIP..."

# Initial Connect
# Redirect Standard Error (2>&1) to handle ADB errors gracefully
& $AdbPath connect $MiStickIP 2>&1 | Out-Null

while ($true) {
    try {
        # 1. AGGRESSIVE MEDIA CHECK
        $MediaStatus = & $AdbPath -s $MiStickIP shell dumpsys media_session | Select-String "state=PlaybackState {.*state=3"

        # 2. Check if screen is on
        $PowerStatus = & $AdbPath -s $MiStickIP shell dumpsys power | Select-String "mWakefulness=Awake"

        if (-not $PowerStatus) {
            $IdleCounter = 0
            # Optional: Don't log every loop to save disk space, only log state changes
        }
        elseif ($MediaStatus) {
            $IdleCounter = 0
            # Log-Message "Active media playing. Timer reset."
        }
        else {
            $IdleCounter++
            Log-Message "Device Idle: $IdleCounter / $IdleLimitMinutes minutes"

            if ($IdleCounter -ge $IdleLimitMinutes) {
                Log-Message "Idle limit reached. Sending SLEEP command."
                & $AdbPath -s $MiStickIP shell input keyevent 223
                $IdleCounter = 0
            }
        }

        # Re-verify connection occasionally
        if ($IdleCounter % 5 -eq 0) {
            & $AdbPath connect $MiStickIP 2>&1 | Out-Null
        }
    }
    catch {
        Log-Message "Error occurred: $_"
    }

    Start-Sleep -Seconds $CheckInterval
}