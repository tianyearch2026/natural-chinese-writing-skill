[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$source=(Resolve-Path -LiteralPath $InputPath).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$stem=[IO.Path]::GetFileNameWithoutExtension($source)
$working=Join-Path $output ($stem+'_checked.docx')
$pdf=Join-Path $output ($stem+'.pdf')
$record=Join-Path $output ($stem+'_render.json')
if($working -eq $source){throw 'Use a separate checking directory'}
foreach($path in @($working,$pdf,$record)){if(Test-Path -LiteralPath $path){throw ('Output already exists: '+$path)}}
$fonts=& (Join-Path $PSScriptRoot 'font_preflight.ps1') -Mode Check | ConvertFrom-Json
if($fonts.status -ne 'ready') {throw ('MiSans preflight did not pass: '+($fonts | ConvertTo-Json -Depth 8 -Compress))}
Copy-Item -LiteralPath $source -Destination $working
$app=$null
$doc=$null
$engine='unknown'
$stage='office_unavailable'
try {
    $app=New-Object -ComObject Word.Application
    $app.Visible=$false
    $app.DisplayAlerts=0
    $stage='engine_identification'
    $enginePath=[string]$app.Path
    $engine=if($enginePath -match '(?i)wps|kingsoft'){'WPS'}elseif($enginePath -match '(?i)Microsoft Office'){'Microsoft Word'}else{'Word-compatible COM host'}
    $stage='open_failed'
    $doc=$app.Documents.Open($working)
    $stage='field_update_failed'
    $doc.Repaginate()
    $doc.Fields.Update() | Out-Null
    foreach($section in $doc.Sections){$section.Footers.Item(1).Range.Fields.Update() | Out-Null}
    $doc.Repaginate()
    $stage='export_failed'
    $doc.ExportAsFixedFormat($pdf,17)
    $doc.Save()
    $pages=$doc.ComputeStatistics(2)
    $result=@{status='exported';engine=$engine;engine_path=$enginePath;version=[string]$app.Version;pages=$pages;input=$source;checked_docx=$working;pdf=$pdf;font_check=$fonts;visual_review='pending'}
} catch {
    $result=@{status=$stage;engine=$engine;input=$source;message=$_.Exception.Message;visual_review='pending'}
} finally {
    if($doc){try {$doc.Close(0)} catch {}}
    if($app){try {$app.Quit()} catch {}}
}
if($result.status -eq 'exported') {
    # Restore updateFields in the working copy after a WPS save.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::Open($working,[IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry=$zip.GetEntry('word/settings.xml')
        $reader=[IO.StreamReader]::new($entry.Open())
        try {$settings=[xml]$reader.ReadToEnd()} finally {$reader.Dispose()}
        $ns=[Xml.XmlNamespaceManager]::new($settings.NameTable)
        $ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        $node=$settings.SelectSingleNode('/w:settings/w:updateFields',$ns)
        if($null -eq $node){$node=$settings.CreateElement('w','updateFields',$ns.LookupNamespace('w'));$settings.DocumentElement.AppendChild($node) | Out-Null}
        $node.SetAttribute('val',$ns.LookupNamespace('w'),'true') | Out-Null
        $entry.Delete()
        $replacement=$zip.CreateEntry('word/settings.xml')
        $stream=$replacement.Open()
        try {$settings.Save($stream)} finally {$stream.Dispose()}
    } finally {$zip.Dispose()}
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $record -Encoding UTF8
$result | ConvertTo-Json -Depth 10
if($result.status -ne 'exported'){exit 1}
