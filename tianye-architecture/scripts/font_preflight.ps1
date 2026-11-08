[CmdletBinding()]
param(
    [ValidateSet('Check','Ensure')][string]$Mode='Check',
    [switch]$AcceptLicense,
    [string]$FontDirectory,
    [switch]$LibraryOnly
)
$ErrorActionPreference='Stop'

function Get-FontInventory {
    $result=@()
    foreach($scope in @('HKCU:','HKLM:')) {
        $key=$scope+'\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        if(-not (Test-Path -LiteralPath $key)){continue}
        $properties=Get-ItemProperty -LiteralPath $key
        foreach($item in $properties.PSObject.Properties) {
            if($item.Name -notmatch '^MiSans(?:\s|$)'){continue}
            $path=[Environment]::ExpandEnvironmentVariables([string]$item.Value)
            if(-not [IO.Path]::IsPathRooted($path)){$path=Join-Path $env:WINDIR ('Fonts\'+$path)}
            $result+=[pscustomobject]@{name=$item.Name;path=$path;exists=(Test-Path -LiteralPath $path)}
        }
    }
    return $result
}

function Get-VisibleFontNames {
    Add-Type -AssemblyName System.Drawing
    $collection=New-Object System.Drawing.Text.InstalledFontCollection
    try {return @($collection.Families | ForEach-Object Name)} finally {$collection.Dispose()}
}

function Get-MiSansStatus {
    param([object[]]$Entries,[string[]]$Visible)
    $regular=@($Entries | Where-Object {$_.exists -and $_.name -match '^MiSans(?: Regular)?\s*\(TrueType\)$'})
    $bold=@($Entries | Where-Object {$_.exists -and $_.name -match '^MiSans Bold\s*\(TrueType\)$'})
    $missing=@()
    if($regular.Count -eq 0){$missing+='Regular'}
    if($bold.Count -eq 0){$missing+='Bold'}
    $visibleFamily=@($Visible | Where-Object {$_ -eq 'MiSans'}).Count -gt 0
    return [pscustomobject]@{ready=($missing.Count -eq 0 -and $visibleFamily);missing=$missing;family_visible=$visibleFamily;entries=@($Entries)}
}

function Get-FailureStage {
    param([Exception]$Exception,[string]$Stage)
    if($Exception -is [UnauthorizedAccessException]){return 'permission_denied'}
    return $Stage
}

function Copy-NewFontFile {
    param([string]$Source,[string]$Target)
    [IO.File]::Copy($Source,$Target,$false)
}

function Install-MiSansFiles {
    param([object[]]$Fonts,[string]$Destination,[string]$RegistryPath)
    $addedFiles=New-Object System.Collections.Generic.List[string]
    $addedNames=New-Object System.Collections.Generic.List[string]
    $mutex=[Threading.Mutex]::new($false,'Local\TianyeMiSansDeployment')
    $acquired=$false
    try {
        try {$acquired=$mutex.WaitOne(10000)} catch [Threading.AbandonedMutexException] {$acquired=$true}
        if(-not $acquired){throw [TimeoutException]::new('Another MiSans deployment is still running')}
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        foreach($font in $Fonts) {
            $target=Join-Path $Destination ([IO.Path]::GetFileName($font.path))
            if(Test-Path -LiteralPath $target) {
                if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $font.path -Algorithm SHA256).Hash) {
                    throw [IO.IOException]::new('Existing font differs; it was preserved: '+$target)
                }
            } else {
                Copy-NewFontFile -Source $font.path -Target $target
                $addedFiles.Add($target)
            }
            $name='MiSans'+$(if($font.weight -eq 'Bold'){' Bold'}else{''})+' (TrueType)'
            $existing=Get-ItemProperty -LiteralPath $RegistryPath -Name $name -ErrorAction SilentlyContinue
            if($null -ne $existing) {
                if([string]$existing.$name -ne $target){throw [IO.IOException]::new('Existing font registration differs; it was preserved: '+$name)}
            } else {
                New-Item -Path $RegistryPath -Force | Out-Null
                New-ItemProperty -LiteralPath $RegistryPath -Name $name -Value $target -PropertyType String | Out-Null
                $addedNames.Add($name)
            }
        }
        return @($Fonts)
    } catch {
        foreach($name in $addedNames){Remove-ItemProperty -LiteralPath $RegistryPath -Name $name -ErrorAction SilentlyContinue}
        foreach($path in $addedFiles){Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
        throw
    } finally {
        if($acquired){$mutex.ReleaseMutex()}
        $mutex.Dispose()
    }
}

function Invoke-FontPreflight {
    $stage='check_failed'
    $work=$null
    try {
        $state=Get-MiSansStatus -Entries @(Get-FontInventory) -Visible @(Get-VisibleFontNames)
        if($state.ready){return @{status='ready';installed_now=$false;check=$state;render_verified=$false}}
        if($Mode -eq 'Check'){return @{status='missing_or_not_visible';check=$state;render_verified=$false}}
        if($state.missing.Count -eq 0){return @{status='restart_application_required';check=$state;render_verified=$false}}
        if(-not $AcceptLicense){return @{status='license_required';check=$state;official_page='https://hyperos.mi.com/font/zh/download/'}}
        $source=$FontDirectory
        if(-not $source) {
            $stage='download_failed'
            $config=Get-Content -LiteralPath (Join-Path $PSScriptRoot '../assets/font_sources.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $uri=[Uri]$config.package_url
            if($uri.Scheme -ne 'https' -or $uri.Host -ne 'hyperos.mi.com'){throw 'Font source is not the verified Xiaomi host'}
            $work=Join-Path ([IO.Path]::GetTempPath()) ('tianye-font-'+[guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $work | Out-Null
            $archive=Join-Path $work 'misans.zip'
            Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $archive -UseBasicParsing -TimeoutSec 120
            $stage='extract_failed'
            # Extract only the required static fonts; never expand arbitrary archive paths.
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip=[IO.Compression.ZipFile]::OpenRead($archive)
            try {
                foreach($entry in $zip.Entries) {
                    if($entry.Name -match '^MiSans-(Regular|Bold)\.(otf|ttf)$') {
                        $target=Join-Path $work $entry.Name
                        if(-not (Test-Path -LiteralPath $target)){[IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target)}
                    }
                }
            } finally {$zip.Dispose()}
            $source=$work
        }
        $stage='font_validation_failed'
        $fonts=@()
        foreach($weight in $state.missing) {
            $candidate=Get-ChildItem -LiteralPath $source -Recurse -File | Where-Object {$_.Name -match ('^MiSans-'+$weight+'\.(otf|ttf)$')} | Select-Object -First 1
            if($null -eq $candidate){throw ('Official font package is missing '+$weight)}
            Add-Type -AssemblyName System.Drawing
            $private=New-Object System.Drawing.Text.PrivateFontCollection
            try {
                $private.AddFontFile($candidate.FullName)
                if(@($private.Families | Where-Object Name -eq 'MiSans').Count -eq 0){throw ('Font internal family is not MiSans: '+$candidate.Name)}
            } finally {$private.Dispose()}
            $fonts+=[pscustomobject]@{path=$candidate.FullName;weight=$weight}
        }
        $stage='install_failed'
        $destination=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $registry='HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        Install-MiSansFiles -Fonts $fonts -Destination $destination -RegistryPath $registry | Out-Null
        $stage='refresh_failed'
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TianyeFontNative {
 [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string file,uint flags,IntPtr reserved);
 [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hwnd,uint msg,IntPtr w,IntPtr l,uint flags,uint timeout,out IntPtr result);
}
'@
        foreach($font in $fonts){[TianyeFontNative]::AddFontResourceEx((Join-Path $destination ([IO.Path]::GetFileName($font.path))),0,[IntPtr]::Zero) | Out-Null}
        $ignored=[IntPtr]::Zero
        [TianyeFontNative]::SendMessageTimeout([IntPtr]0xffff,0x001D,[IntPtr]::Zero,[IntPtr]::Zero,2,1000,[ref]$ignored) | Out-Null
        $check=Get-MiSansStatus -Entries @(Get-FontInventory) -Visible @(Get-VisibleFontNames)
        $status=if($check.ready){'ready'}else{'restart_application_required'}
        return @{status=$status;installed_now=$true;check=$check;render_verified=$false}
    } catch {
        return @{status=(Get-FailureStage -Exception $_.Exception -Stage $stage);message=$_.Exception.Message;render_verified=$false}
    } finally {
        if($work -and (Test-Path -LiteralPath $work)) {
            # This is the exact GUID directory created above, never caller input.
            $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
            $resolved=[IO.Path]::GetFullPath($work)
            if($resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -match '^tianye-font-[a-f0-9]{32}$') {
                Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

if(-not $LibraryOnly){Invoke-FontPreflight | ConvertTo-Json -Depth 8}
