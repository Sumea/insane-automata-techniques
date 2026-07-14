[CmdletBinding(
    DefaultParameterSetName='Distance',
    SupportsShouldProcess
)]
param(
    # Quality mode (mutually exclusive)
    [Parameter(ParameterSetName='Distance')]
    [Alias("d")]
    [ValidateRange(0,25)]
    [double]$Distance = 1.0,

    [Parameter(ParameterSetName='Quality')]
    [Alias("q")]
    [ValidateRange(0,100)]
    [int]$Quality,

    # General
    [Alias("s")]
    [string]$Suffix,

    [Alias("e")]
    [ValidateRange(1,10)]
    [int]$Effort = 7,

    [Alias("a")]
    [ValidateRange(0,25)]
    [double]$AlphaDistance,

    [Alias("t")]
    [int]$Threads,

    [Alias("p")]
    [switch]$Progressive,

    [Alias("m")]
    [switch]$Modular,

    [Alias("j")]
    [switch]$LosslessJPEG,

    [Alias("pn")]
    [int]$PhotonNoiseISO,

    [Alias("fd")]
    [ValidateRange(0,4)]
    [int]$FasterDecoding,

    [Alias("be")]
    [ValidateRange(1,11)]
    [int]$BrotliEffort,

    [Alias("r")]
    [switch]$RecycleOriginal,

    [Alias("dir")]
    [string]$OutputDirectory,

    [Alias("h","?")]
    [switch]$Help
)

Add-Type -AssemblyName Microsoft.VisualBasic

if ($Help) {
@"
Usage:
    jxl-bats.ps1 [-d DISTANCE | -q QUALITY] [options]

Quality:
  -d, -Distance <0-25>          Butteraugli distance (default 1.0)
  -q, -Quality <0-100>          Quality setting

General:
  -e, -Effort <1-10>            Encoder effort (default 7)
  -s, -Suffix <text>            Output suffix (default x)
  -a, -AlphaDistance <0-25>     Quality distance for alpha channel (Defaul 0.0)
  -t, -Threads <-1..n>          Worker threads (-1 = automatic)
  -p, -Progressive
  -m, -Modular
  -j, -LosslessJPEG
      Preserve JPEG bitstream when input is JPEG
  -pn, -PhotonNoiseISO <ISO>
  -fd, -FasterDecoding <0-4>
  -be,  -Brotli Effort <1-11>
  -dir <name>   Create subfolder for output
  -r Move original to Recycle Bin (if output is smaller)
  -h, -Help

Examples:

    .\jxl-bats.ps1

    .\jxl-bats.ps1 -d 0.8 -e 9

    .\jxl-bats.ps1 -q 92 -p

    .\jxl-bats.ps1 -j -s .dd -dir compressed
"@
    return
}

if ($PSBoundParameters.ContainsKey('OutputDirectory')) {

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }

    $OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
}

$files = Get-ChildItem -File | Where-Object Extension -in @(
    '.png','.apng','.gif','.jpg','.jpeg',
    '.ppm','.pnm','.pfm','.pam','.pgx'
)
if ($files.Count -eq 0) {
    Write-Warning "No input files found."
    return
}

foreach ($file in $files) {

switch ($true) {
    { $PSBoundParameters.ContainsKey('Suffix') } { }
    { $LosslessJPEG }                            { $Suffix = '.jpg'; break }
    { $Modular }                                { $Suffix = '.md'; break }
    { $Distance -eq 0 }                         { $Suffix = '.ll'; break }
    default                                     { $Suffix = '' }
}

$outputName = "$($file.BaseName)$Suffix.jxl"

if ($PSBoundParameters.ContainsKey('OutputDirectory')) {
    $output = Join-Path $OutputDirectory $outputName
}
else {
    $output = $outputName
}

    $args = @(
        $file.Name
        $output
    )

    # Quality selection
    if ($PSBoundParameters.ContainsKey('Quality')) {
        $args += '-q', $Quality
    }
    else {
        $args += '-d', $Distance
    }

    # Always specify effort
    $args += @("-e", $Effort)

    if ($PSBoundParameters.ContainsKey("AlphaDistance")) {
        $args += @("-a", $AlphaDistance)
    }

    if ($PSBoundParameters.ContainsKey('Threads')) {
        $args += "--num_threads=$Threads"
    }

    if ($Progressive) {
        $args += "--progressive"
    }

    if ($Modular) {
        $args += "--modular=1"
    }

    if ($LosslessJPEG) {
        $args += "--lossless_jpeg=1"
    }    
    else {
        $args += "--lossless_jpeg=0"
    }

    if ($PSBoundParameters.ContainsKey("PhotonNoiseISO")) {
        $args += "--photon_noise_iso=$PhotonNoiseISO"
    }

    if ($PSBoundParameters.ContainsKey("FasterDecoding")) {
        $args += "--faster_decoding=$FasterDecoding"
    }

    if ($PSBoundParameters.ContainsKey("BrotliEffort")) {
        $args += "--brotli_effort=$BrotliEffort"
    }

    Write-Verbose ("cjxl.exe " + ($args -join ' '))
    
    if ($PSCmdlet.ShouldProcess($file.Name, "Encode to $output")) {
    & cjxl.exe @args

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "cjxl failed for $($file.Name)"
        continue
    }

    if (-not (Test-Path $output)) {
        Write-Warning "Output file was not created: $output"
        continue
    }

    $outputFile = Get-Item $output
    }

if ($RecycleOriginal -and $outputFile.Length -lt $file.Length) {

    Write-Verbose "Recycling $($file.Name)"

    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
        $file.FullName,
        [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
        [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
    )
}

$saved = $file.Length - $outputFile.Length
$percent = [math]::Round($saved * 100 / $file.Length, 1)

Write-Host "$($file.Name): saved $saved bytes ($percent%)"

}