param([Parameter(Mandatory=$true)][string]$ScratchDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/font_preflight.ps1') -LibraryOnly
$regular=[pscustomobject]@{name='MiSans (TrueType)';path='regular.otf';exists=$true}
$bold=[pscustomobject]@{name='MiSans Bold (TrueType)';path='bold.otf';exists=$true}
$ready=Get-MiSansStatus -Entries @($regular,$bold) -Visible @('MiSans')
if(-not $ready.ready){throw 'Complete inventory failed'}
$missing=Get-MiSansStatus -Entries @($regular) -Visible @('MiSans')
if($missing.ready -or @($missing.missing).Count -ne 1 -or $missing.missing[0] -ne 'Bold'){throw 'Missing-bold detection failed'}
$broken=[pscustomobject]@{name='MiSans Bold (TrueType)';path='gone.otf';exists=$false}
if((Get-MiSansStatus -Entries @($regular,$broken) -Visible @('MiSans')).ready){throw 'Broken registration accepted'}
if((Get-MiSansStatus -Entries @($regular,$bold) -Visible @('Other Font')).ready){throw 'Invisible family accepted'}
if((Get-FailureStage -Exception ([UnauthorizedAccessException]::new('blocked')) -Stage 'install_failed') -ne 'permission_denied'){throw 'Permission classification failed'}

# Exercise actual deployment's denied-copy path using an isolated mock. Registry
# functions throw if unexpectedly reached; real fonts and registry are untouched.
New-Item -ItemType Directory -Path $ScratchDirectory -Force | Out-Null
$target=Join-Path $ScratchDirectory ('denied-'+[guid]::NewGuid().ToString('N'))
function Copy-NewFontFile {throw [UnauthorizedAccessException]::new('simulated denied copy')}
function Get-ItemProperty {throw 'Registry must not be reached during denied-copy test'}
$blocked=$false
try {
    Install-MiSansFiles -Fonts @([pscustomobject]@{path='MiSans-Bold.otf';weight='Bold'}) -Destination $target -RegistryPath 'HKCU:\THIS_TEST_MUST_NEVER_BE_WRITTEN' | Out-Null
} catch {
    $blocked=$_.Exception -is [UnauthorizedAccessException]
}
if(-not $blocked -or @(Get-ChildItem -LiteralPath $target -File).Count -gt 0){throw 'Denied deployment did not stop cleanly'}
Remove-Item Function:\Copy-NewFontFile
Remove-Item Function:\Get-ItemProperty
$Mode='Ensure'
$AcceptLicense=$false
function Get-FontInventory {return @($regular)}
function Get-VisibleFontNames {return @('MiSans')}
if((Invoke-FontPreflight).status -ne 'license_required'){throw 'Missing fonts attempted installation without license confirmation'}
function Get-FontInventory {return @($regular,$bold)}
if((Invoke-FontPreflight).installed_now){throw 'Already installed fonts were deployed again'}
@{passed=$true;tests=@('complete_inventory','missing_bold','stale_registration','family_not_visible','permission_classification','denied_copy_stops_without_registry','license_required_before_download','ensure_existing_is_idempotent');installation='simulated_failure_only'} | ConvertTo-Json
