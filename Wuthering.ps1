Add-Type -AssemblyName System.Web
$gamePath = $null
$urlFound = $false
$logFound = $false
$folderFound = $false
$err = ""
$checkedDirectories = @()

Write-Output "Attempting to find URL automatically..."

#Args: [0] - $gamepath
function LogCheck {
    if (!(Test-Path $args[0])) {
        $folderFound = $false
        $logFound = $false
        $urlFound = $false
        return $folderFound, $logFound, $urlFound
    }
    else {
        $folderFound = $true
    }
    $gachaLogPath = $args[0] + '\Client\Saved\Logs\Client.log'
    $debugLogPath = $args[0] + '\Client\Binaries\Win64\ThirdParty\KrPcSdk_Global\KRSDKRes\KRSDKWebView\debug.log'

    if (Test-Path $gachaLogPath) {
        $logFound = $true
        $gachaUrlEntry = Get-Content $gachaLogPath | Select-String -Pattern "https://aki-gm-resources(-oversea)?\.aki-game\.(net|com)/aki/gacha/index\.html#/record*" | Select-Object -Last 1
        if ([string]::IsNullOrWhiteSpace($gachaUrlEntry)) {
            $gachaUrlEntry = $null
        }
    }
    else {
        $gachaUrlEntry = $null
    }

    if (Test-Path $debugLogPath) {
        $logFound = $true
        $debugUrlEntry = Get-Content $debugLogPath | Select-String -Pattern '"#url": "(https://aki-gm-resources(-oversea)?\.aki-game\.(net|com)/aki/gacha/index\.html#/record[^"]*)"' | Select-Object -Last 1
        if ([string]::IsNullOrWhiteSpace($debugUrlEntry)) {
            $debugUrl = $null
        }
        else {
            $debugUrl = $debugUrlEntry.Matches.Groups[1].Value
        }
    }
    else {
        $debugUrl = $null
    }

    if ($gachaUrlEntry -or $debugUrl) {
        if ($gachaUrlEntry) {
            $urlToCopy = $gachaUrlEntry -replace '.*?(https://aki-gm-resources(-oversea)?\.aki-game\.(net|com)[^"]*).*', '$1'
            Write-Host "URL found in $($gachaLogPath)"
        }
        if ([string]::IsNullOrWhiteSpace($urlToCopy)) {
            $urlToCopy = $debugUrl
            Write-Host "URL found in $($debugLogPath)"
        }

        if (![string]::IsNullOrWhiteSpace($urlToCopy)) {
            $urlFound = $true
            Write-Host "`nConvene Record URL: $urlToCopy"
            Set-Clipboard $urlToCopy
            Write-Host "`nLink copied to clipboard, paste it in https://mc.appfeng.com/gachaLog and click the Import History button." -ForegroundColor Green
        }
    }
    return $folderFound, $logFound, $urlFound
}


# MUI Cache
if (!$urlFound) {
    $muiCachePath = "Registry::HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    $filteredEntries = (Get-ItemProperty -Path $muiCachePath).PSObject.Properties | Where-Object { $_.Value -like "*wuthering*" } | Where-Object { $_.Name -like "*client-win64-shipping.exe*" }
    if ($filteredEntries.Count -ne 0) {
        $err += "MUI Cache($($filteredEntries.Count)):`n"
        foreach ($entry in $filteredEntries) {
            $gamePath = ($entry.Name -split '\\client\\')[0]
            if ($gamePath -like "*OneDrive*") {
              $err += "Skipping path as it contains 'OneDrive': $($gamePath)n"
              continue
            }

            if ($gamePath -in $checkedDirectories) {
                $err += "Already checked: $($gamePath)`n"
                continue
            }
            $checkedDirectories += $gamePath
            $folderFound, $logFound, $urlFound = LogCheck $gamePath
            if ($urlFound) { break }
            elseif ($logFound) {
                $err += "Path checked: $($gamePath).`n"
                $err += "Cannot find the convene history URL in both Client.log and debug.log! Please open your Convene History first!`n"
                $err += "Contact Us if you think this is correct directory and still facing issues.`n"
            }
            elseif ($folderFound) {
                $err += "No logs found at $gamePath`n"
            }
            else {
                $err += "No Installation found at $gamePath`n"
            }
        }
        if ($urlFound) { break }
    }
    else {
        $err += "No entries found in MUI Cache.`n"
    }
}

# Firewall 
if (!$urlFound) {
    $firewallPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
    $filteredEntries = (Get-ItemProperty -Path $firewallPath).PSObject.Properties | Where-Object { $_.Value -like "*wuthering*" } | Where-Object { $_.Name -like "*client-win64-shipping*" }
    if ($filteredEntries.Count -ne 0) {
        $err += "Firewall($($filteredEntries.Count)):`n"
        foreach ($entry in $filteredEntries) {
            $gamePath = (($entry.Value -split 'App=')[1] -split '\\client\\')[0]
            if ($gamePath -like "*OneDrive*") {
              $err += "Skipping path as it contains 'OneDrive': $($gamePath)n"
              continue
            }

            if ($gamePath -in $checkedDirectories) {
                $err += "Already checked: $($gamePath)`n"
                continue
            }

            $checkedDirectories += $gamePath
            $folderFound, $logFound, $urlFound = LogCheck $gamePath
            if ($urlFound) { break }
            elseif ($logFound) {
                $err += "Path checked: $($gamePath).`n"
                $err += "Cannot find the convene history URL in both Client.log and debug.log! Please open your Convene History first!`n"
                $err += "Contact Us if you think this is correct directory and still facing issues.`n"
            }
            elseif ($folderFound) {
                $err += "No logs found at $gamePath`n"
            }
            else {
                $err += "No Installation found at $gamePath`n"
            }
        }
        if ($urlFound) { break }
    }
    else {
        $err += "No entries found in firewall.`n"
    }
}

# Native
if (!$urlFound) {
    $64 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $32 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    try {
        $gamePath = (Get-ItemProperty -Path $32, $64 | Where-Object { $_.DisplayName -like "*wuthering*" } | Select-Object -ExpandProperty InstallPath)
        if ($gamePath) {
            if ($gamePath -like "*OneDrive*") {
              $err += "Skipping path as it contains 'OneDrive': $($gamePath)n"
              continue
            }

            if ($gamePath -in $checkedDirectories) {
                $err += "Already checked: $($gamePath)`n"
                continue
            }
            $checkedDirectories += $gamePath
            $folderFound, $logFound, $urlFound = LogCheck $gamePath
            if ($urlFound) { break }
            elseif ($logFound) {
                $err += "Path checked: $($gamePath).`n"
                $err += "Cannot find the convene history URL in both Client.log and debug.log! Please open your Convene History first!`n"
                $err += "Contact Us if you think this is correct directory and still facing issues.`n"
            }
            elseif ($folderFound) {
                $err += "No logs found at $gamePath`n"
            }
            else {
                $err += "No Installation found at $gamePath`n"
            }
        }
        else {
            $err += "No Entry found for Native Client.`n"
        }
    }
    catch {
        Write-Output "Error accessing registry: $_"
        $gamePath = $null
        $urlFound = $false
    }  
}

# Common Installation Paths
if (!$urlFound) {
    $diskLetters = (Get-PSDrive -PSProvider FileSystem).Name
    foreach ($diskLetter in $diskLetters) {
        $gamePaths = @(
            "$diskLetter`:\Wuthering Waves Game",
            "$diskLetter`:\Wuthering Waves\Wuthering Waves Game",
            "$diskLetter`:\Program Files\Epic Games\WutheringWavesj3oFh"
            "$diskLetter`:\Program Files\Epic Games\WutheringWavesj3oFh\Wuthering Waves Game"
        )
    
        foreach ($path in $gamePaths) {
            if (!(Test-Path $path)) {
                continue
            }
            if ($gamePath -like "*OneDrive*") {
              $err += "Skipping path as it contains 'OneDrive': $($gamePath)n"
              continue
            }

            if ($path -in $checkedDirectories) {
                $err += "Already checked: $($path)`n"
                continue
            }
            $checkedDirectories += $path
            $folderFound, $logFound, $urlFound = LogCheck $path
            if ($urlFound) { break }
            elseif ($logFound) {                
                $err += "Path checked: $($gamePath).`n"
                $err += "Cannot find the convene history URL in both Client.log and debug.log! Please open your Convene History first!`n"
                $err += "Contact Us if you think this is correct directory and still facing issues.`n"
            }
            elseif ($folderFound) {
                $err += "No logs found at $path`n"
            }
            else {
                $err += "No Installation found at $path`n"
            }
        }
        if ($urlFound) { break }
    }
    if ($urlFound) { break }
    $err += "No URL Found in Common Installation Paths`n"
}

Write-Host $err -ForegroundColor Magenta

# Manual
while (!$urlFound) {
    Write-Host "Game install location not found or log files missing." -ForegroundColor Red
    Write-Host "Otherwise, please enter the game install location path."
    Write-Host 'Common install locations:'
    Write-Host '  C:\Wuthering Waves' -ForegroundColor Yellow
    Write-Host '  C:\Wuthering Waves\Wuthering Waves Game' -ForegroundColor Yellow
    Write-Host 'For EGS:'
    Write-Host '  C:\Program Files\Epic Games\WutheringWavesj3oFh' -ForegroundColor Yellow
    Write-Host '  C:\Program Files\Epic Games\WutheringWavesj3oFh\Wuthering Waves Game' -ForegroundColor Yellow
    $path = Read-Host "Path(Type exit to quit)"
    if ($path) {
        if ($path.ToLower() -eq "exit") {
            break
        }
        $gamePath = $path
        Write-Host "`n`n`nUser provided path: $($path)" -ForegroundColor Magenta
        $folderFound, $logFound, $urlFound = LogCheck $path
        if ($urlFound) { break }
        elseif ($logFound) {            
            $err += "Path checked: $($gamePath).`n"
            $err += "Cannot find the convene history URL in both Client.log and debug.log! Please open your Convene History first!`n"
            $err += "Contact Us if you think this is correct directory and still facing issues.`n"
        }
        elseif ($folderFound) {
            Write-Host "No logs found at $gamePath`n"
        }
        else {
            Write-Host "Folder not found in user-provided path: $path"
            Write-Host "Could not find log files. Did you set your game location properly or open your Convene History first?" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Invalid game location. Did you set your game location properly?" -ForegroundColor Red
    }
}
