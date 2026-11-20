[CmdletBinding()]
param([string] $Circuit = (Join-Path $PSScriptRoot 'ex1.circ'))

$ErrorActionPreference = 'Stop'

function Invoke-Logisim([string] $Executable, [string[]] $Arguments) {
    $config = New-Object System.Diagnostics.ProcessStartInfo
    $config.FileName = $Executable
    $config.Arguments = ($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $config.UseShellExecute = $false
    $config.RedirectStandardOutput = $true
    $config.RedirectStandardError = $true
    $config.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($config)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) {
            $process.Kill()
            throw 'Logisim timed out.'
        }
        return @{ ExitCode = $process.ExitCode; Output = $stdout.Result; Error = $stderr.Result }
    } finally {
        $process.Dispose()
    }
}

function Read-TruthTable([string] $Text, [string[]] $ExpectedColumns, [string] $OutputPin) {
    $lines = @($Text -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($lines.Count -lt 2) { throw 'Logisim did not print a truth table.' }
    $columns = $lines[0] -split '\s+'
    $indices = @($ExpectedColumns | ForEach-Object { [Array]::IndexOf($columns, $_) })
    if ($columns.Count -ne $ExpectedColumns.Count -or ($indices -contains -1)) {
        throw ('Pin names must be ' + ($ExpectedColumns -join ', ') + '.')
    }

    $table = @{}
    foreach ($line in $lines[1..($lines.Count-1)]) {
        $cells = $line -split '\s+'
        if ($cells.Count -ne $columns.Count) { throw 'Logisim returned an incomplete truth table.' }
        $key = ($indices[0..($indices.Count-2)] | ForEach-Object { $cells[$_] }) -join ' '
        if ($table.ContainsKey($key)) { throw "Logisim repeated input $key." }
        $table[$key] = $cells[[Array]::IndexOf($columns, $OutputPin)]
    }
    return $table
}

try {
    $inputFile = Get-Item -LiteralPath $Circuit
    if ($inputFile.PSIsContainer -or $inputFile.Name -cne 'ex1.circ') {
        throw 'Select your ex1.circ file.'
    }

    $launchers = @()
    if ($env:LOGISIM_EXE) {
        $launchers = @((Get-Item -LiteralPath $env:LOGISIM_EXE).FullName)
    } else {
        $launchers = @(Get-Command logisim-evolution, logisim -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Source -Unique)
    }

    $launcher = $null
    foreach ($candidate in $launchers) {
        $version = Invoke-Logisim $candidate @('--version')
        if ($version.ExitCode -eq 0 -and ($version.Output + $version.Error) -match '(?im)Logisim-evolution\s+v?5\.0\.0\b') {
            $launcher = $candidate
            break
        }
    }
    if (-not $launcher) {
        throw 'Logisim-evolution 5.0.0 was not found. Install the SI100B version, then reopen PowerShell. If needed, set LOGISIM_EXE to the full path of the installed executable.'
    }

    $failed = 0
    foreach ($case in @('NAND1','NOR1','XOR1','MUX2','MUX4')) {
        try {
            $reference = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "vectors/$case.txt")
            $columns = ($reference -split '\r?\n')[0].Trim() -split '\s+'
            $expected = Read-TruthTable $reference $columns 'RESULT'
            $run = Invoke-Logisim $launcher @('--tty', 'table', '--toplevel-circuit', $case, $inputFile.FullName)
            if ($run.ExitCode -ne 0) { throw "Logisim could not simulate $case." }
            $actual = Read-TruthTable $run.Output $columns 'RESULT'
            $matched = 0
            $example = $null
            foreach ($key in ($expected.Keys | Sort-Object)) {
                if ($actual.ContainsKey($key) -and $actual[$key] -ceq $expected[$key]) {
                    $matched++
                } elseif (-not $example) {
                    $seen = if ($actual.ContainsKey($key)) { $actual[$key] } else { 'missing' }
                    $example = "Input $key -> $seen (expected $($expected[$key]))."
                }
            }
            if ($matched -eq $expected.Count -and $actual.Count -eq $expected.Count) {
                Write-Host "PASS $case ($matched/$($expected.Count))"
            } else {
                $failed++
                Write-Host "FAIL $case ($matched/$($expected.Count)) $example"
            }
        } catch {
            $failed++
            Write-Host "FAIL $case - $($_.Exception.Message)"
        }
    }
    if ($failed) { exit 1 }
    exit 0
} catch {
    Write-Host "ERROR - $($_.Exception.Message)"
    exit 2
}
