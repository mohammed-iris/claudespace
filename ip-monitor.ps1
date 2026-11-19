<#
.SYNOPSIS
    Shows your current public and local IP addresses, refreshing in real time.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\ip-monitor.ps1 -Interval 3
#>
param(
    [ValidateRange(1, 3600)]
    [int]$Interval = 3
)

$ErrorActionPreference = 'SilentlyContinue'

$providers = @(
    'https://api.ipify.org',
    'https://ifconfig.me/ip',
    'https://icanhazip.com',
    'https://checkip.amazonaws.com'
)

function Get-PublicIP {
    foreach ($url in $providers) {
        try {
            $ip = (Invoke-RestMethod -Uri $url -TimeoutSec 5 -UseBasicParsing).ToString().Trim()
            if ($ip -match '^[0-9a-fA-F\.:]+$') { return $ip }
        } catch { }
    }
    return $null
}

function Get-LocalIPs {
    if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
        Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            ForEach-Object { [pscustomobject]@{ Interface = $_.InterfaceAlias; IP = $_.IPAddress } }
    } else {
        [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
            Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.ToString() -notlike '127.*' } |
            ForEach-Object { [pscustomobject]@{ Interface = '-'; IP = $_.ToString() } }
    }
}

$lastIP  = $null
$history = New-Object System.Collections.Generic.List[string]

try {
    while ($true) {
        $now      = Get-Date
        $publicIP = Get-PublicIP
        $locals   = @(Get-LocalIPs)

        $changed = $false
        if ($publicIP -and $publicIP -ne $lastIP) {
            if ($lastIP) {
                $changed = $true
                [console]::Beep(1000, 200)
            }
            $history.Insert(0, "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f $now, $publicIP)
            if ($history.Count -gt 10) { $history.RemoveAt(10) }
            $lastIP = $publicIP
        }

        Clear-Host
        Write-Host "=== IP Monitor ===  (refresh every $Interval s, Ctrl+C to quit)" -ForegroundColor Cyan
        Write-Host ("Last check : {0:yyyy-MM-dd HH:mm:ss}" -f $now)
        Write-Host ""

        Write-Host -NoNewline "Public IP  : "
        if (-not $publicIP) {
            Write-Host "OFFLINE / unavailable" -ForegroundColor Red
        } elseif ($changed) {
            Write-Host "$publicIP  << CHANGED" -ForegroundColor Yellow
        } else {
            Write-Host $publicIP -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "Local IPv4 :" -ForegroundColor Cyan
        if ($locals.Count -eq 0) {
            Write-Host "  (none)" -ForegroundColor DarkGray
        } else {
            $locals | ForEach-Object { Write-Host ("  {0,-25} {1}" -f $_.Interface, $_.IP) }
        }

        Write-Host ""
        Write-Host "Public IP history:" -ForegroundColor Cyan
        $history | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

        Start-Sleep -Seconds $Interval
    }
} finally {
    Write-Host "`nStopped." -ForegroundColor Cyan
}
