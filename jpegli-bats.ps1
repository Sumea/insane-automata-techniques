[CmdletBinding(
    DefaultParameterSetName='Distance',
    SupportsShouldProcess
)]
param(
    # Encoding mode (mutually exclusive)
    [Parameter(ParameterSetName = "Distance")]
    [Alias('d')]
    [double]$Distance = 1.0,

    [Parameter(ParameterSetName = "Quality")]
    [Alias('q')]
    [ValidateRange(1,100)]
    [int]$Quality,

    # General options
    [Alias('s')]
    [string]$Suffix,

    [Alias('p')]
    [ValidateRange(0,2)]
    [int]$ProgressiveLevel = 2,

    [Alias('c')]
    [ValidateSet('444','440','422','420')]
    [string]$ChromaSubsampling,

    [Alias("r")]
    [switch]$RecycleOriginal,

    [Alias("dir")]
    [string]$OutputDirectory,

    [Alias('h','?')]
    [switch]$Help
)

Add-Type -AssemblyName Microsoft.VisualBasic

if ($Help) {
    @"
Usage:
    jpegli-bats.ps1 [-d distance | -q quality] [options]

Options:
  -d, -Distance <n>          Butteraugli distance (default 1.0)
  -q, -Quality <1-100>       JPEG quality
  -s, -Suffix <text>         Output suffix (default: .li)
  -p, -ProgressiveLevel <0-2>
  -dir <name>   Create subfolder for output
  -r Move original to Recycle Bin (if output is smaller)  
  -c, -ChromaSubsampling 444|440|422|420
  -h, -? -Help (you are here)
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
    '.ppm','.pnm','.pfm','.pam','.pgx','.exr'
)
if ($files.Count -eq 0) {
    Write-Warning "No input files found."
    return
}

foreach ($file in $files) {

$outputName = "$($file.BaseName)$Suffix.jpg"

    if ($PSBoundParameters.ContainsKey('OutputDirectory')) {
        $output = Join-Path $OutputDirectory $outputName
    }
    else {
        $output = $outputName
    }

    # Build the command line
    $args = @(
        $file.Name
        $output
    )

    if ($PSBoundParameters.ContainsKey('Quality')) {
        $args += @('-q', $Quality)
    }
    else {
        $args += @('-d', $Distance)
    }

    if ($PSBoundParameters.ContainsKey('ProgressiveLevel')) {
        $args += @('-p', $ProgressiveLevel)
    }

    if ($PSBoundParameters.ContainsKey('ChromaSubsampling')) {
        $args += "--chroma_subsampling=$ChromaSubsampling"
    }  

    Write-Verbose ("cjpegli.exe " + ($args -join ' '))

    if ($PSCmdlet.ShouldProcess($file.Name, "Encode to $output")) {
        & cjpegli.exe @args

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "cjpegli failed for $($file.Name)"
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