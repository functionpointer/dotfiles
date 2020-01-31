#
# PowerShell profile: functions
#

if ((Get-Variable "ColorInfo" -ErrorAction "Ignore") -eq $null) {
    Set-Variable -Name ColorInfo -Value "DarkYellow"
}


# Import popular commands from Linux
if (Get-Command Import-WslCommand -errorAction Ignore) {
    Import-WslCommand "chmod"
    Import-WslCommand "grep"
    Import-WslCommand "head"
    Import-WslCommand "less"
    Import-WslCommand "ls"
    Import-WslCommand "man"
    Import-WslCommand "ssh"
    Import-WslCommand "tail"

    $WslDefaultParameterValues = @{}
    $WslDefaultParameterValues["grep"] = "-E"
    $WslDefaultParameterValues["less"] = "-i"
    $WslDefaultParameterValues["ls"] = "-AFhl --color=auto"

    $WslImportedCommands = @()
    $WslImportedCommands += "chmod"
    $WslImportedCommands += "grep"
    $WslImportedCommands += "head"
    $WslImportedCommands += "less"
    $WslImportedCommands += "ls"
    $WslImportedCommands += "man"
    $WslImportedCommands += "ssh"
    $WslImportedCommands += "tail"
}



# File management
# -----------------------------------------------------------------------------

# Copy files securely
function Copy-Item-Secure {
    <#
    .SYNOPSIS
        Makes an exact copy of files
    .DESCRIPTION
        Creates a copy of source files onto a local or network destination.
    .PARAMETER Source
        The source directory. This can be an absolute or relative path.
    .PARAMETER Destination
        The destination directory. It will be created if needed. This can be an
        absolute or relative path.
    .PARAMETER Flags
        Extra ROBOCOPY parameters.
    .EXAMPLE
       Copy-Item-Secure file.txt .\Destination\
    .EXAMPLE
       Copy-Item-Secure .\Source\*.zip .\Destination\
    .EXAMPLE
       Copy-Item-Secure file.txt .\Destination\ /TIMFIX
    .INPUTS
       String
    .OUTPUTS
       None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    $SourcePath = Split-Path -Path $Source
    if (!$SourcePath) {
        $SourcePath = '.'
    }
    $File = Split-Path -Path $Source -Leaf

    robocopy /COPY:DAT /DCOPY:DAT /LEV:0 /R:1000000 /W:30 $SourcePath $Destination $File
}

# Create empty file or update its timestamp
if (Get-Command Import-WslCommand -errorAction Ignore) {
    Import-WslCommand "touch"
    Set-Alias -Name "New-Item-Empty" -Value "touch"

    if (Test-Path variable:global:WslImportedCommands) {
        $WslImportedCommands += "touch"
    }
}
else {
    function New-Item-Empty {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
            [string]$File
        )

        if (Test-Path $File) {
            (Get-ChildItem $File).LastWriteTime = Get-Date
        }
        else {
            New-Item -ItemType File $File
        }
    }
    Set-Alias -Name "touch" -Value "New-Item-Empty"
}

# Creates directory and change to it
function New-Item-Set-Location {
    <#
    .SYNOPSIS
        Makes a directory and change to it
    .DESCRIPTION
        Creates a directory (if it doesn't already exist) and navigates to it.
    .PARAMETER Path
        The directory to switch to.
    .EXAMPLE
        New-Item-Set-Location .\New-Folder\
    .EXAMPLE
        New-Item-Set-Location .\Existing-Folder\
    .INPUTS
        String
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )

    if (!(Test-Path -path $Path)) {
        mkdir $Path
    }
    cd $Path -passthru
}
Set-Alias -Name "mkcd" -Value New-Item-Set-Location
Set-Alias -Name "take" -Value New-Item-Set-Location

# Mirror paths
function Mirror-Path {
    <#
    .SYNOPSIS
        Makes an exact copy of files and folders
    .DESCRIPTION
        Creates a mirror of a source directory onto a local or network
        destination. Files currently existing at destination but not present
        in the source will be deleted.
    .PARAMETER Source
        The source directory. This can be an absolute or relative path.
    .PARAMETER Destination
        The destination directory. It will be created if needed. This can be an
        absolute or relative path.
    .PARAMETER Files
        File(s) to copy (names/wildcards: default is "*.*").
    .PARAMETER Flags
        Extra ROBOCOPY parameters.
    .EXAMPLE
       Mirror-Path .\Source\ .\Destination\
    .EXAMPLE
       Mirror-Path .\Source\ .\Destination\ *.txt
    .EXAMPLE
       Mirror-Path .\Source\ .\Destination\ *.* /XD:ExcludedDirs
    .INPUTS
       String
    .OUTPUTS
       None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter()]
        [string]$Files = "*.*",

        [Parameter()]
        [string]$Flags
    )

    robocopy /MIR /COPY:DAT /DCOPY:DAT /R:1000000 /W:30 $Source $Destination $Files $Flags
}


# General
# -----------------------------------------------------------------------------

# Repeat a command
# Syntax: "repeat [X] [command]"
function Repeat-Command {
    $max, $command = $args
    if ($command) {
        for ($i=1; $i -le $max; $i++) {
            Invoke-Expression ("$command")
        }
    }
}

function Repeat-Command-Borked {
    <#
    .SYNOPSIS
        Repeat a command multiple times
    .DESCRIPTION
        Allows issuing a command multiple times in a row.
    .PARAMETER Count
        The max number of times to repeat a command.
    .PARAMETER Command
        The command to run. Can include spaces.
    .EXAMPLE
       Repeat-Command 5 echo hello world
    .INPUTS
       String
    .OUTPUTS
       None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Count,

        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    for ($i=1; $i -le $Count; $i++) {
        Invoke-Command -ScriptBlock $Command
    }
}


# Sysadmin
# -----------------------------------------------------------------------------

# Keep all apps and packages up to date
function Update-Packages {
    <#
    .SYNOPSIS
        Keeps all apps and packages up to date
    .DESCRIPTION
        Looks for updates for system modules and help, when proceeds to
        updating any packages by these optional managers: Chocolatey, Choco,
        npm, RubyGems.
    .INPUTS
       None
    .OUTPUTS
       None
    #>

    Write-Host "Updating system modules..." -ForegroundColor $ColorInfo
    Update-Module

    Write-Host "Updating help..." -ForegroundColor $ColorInfo
    Update-Help -Force

    if (Get-Command 'choco' -ErrorAction "Ignore") {
        Write-Host "Updating packages with Chocolatey..." -ForegroundColor $ColorInfo
        choco upgrade all
    }

    if (Get-Command 'scoop' -ErrorAction "Ignore") {
        Write-Host "Updating packages with Scoop..." -ForegroundColor $ColorInfo
        scoop update *
        scoop cleanup *
    }

    if (Get-Command 'npm' -ErrorAction "Ignore") {
        Write-Host "Updating Node.js packages with npm..." -ForegroundColor $ColorInfo
        # npm install npm -g
        npm update -g
    }

    if (Get-Command 'gem' -ErrorAction "Ignore") {
        Write-Host "Updating Ruby gems..." -ForegroundColor $ColorInfo
        gem update --system
        gem update
        gem cleanup
    }
}
Set-Alias -Name "update" -Value Update-Packages


# Varia
# -----------------------------------------------------------------------------

# Display the current weather and forecast
function Get-Weather {
    <#
    .SYNOPSIS
        Display the current weather and forecast
    .DESCRIPTION
        Fetches the weather information from https://wttr.in for terminal
        display.
    .PARAMETER Request
        The full URL to the wttr request.
    .PARAMETER Timeout
        The number of seconds to wait for a response.
    .EXAMPLE
        Get-Weather nF 10
    .INPUTS
        String
    .OUTPUTS
        String
    .LINK
        https://github.com/chubin/wttr.in
    .LINK
        https://wttr.in
    #>
    param (
        [Parameter(Mandatory=$false)]
        [string]$Request,

        [Parameter(Mandatory=$false)]
        [PSDefaultValue(Help = '5')]
        [int]$Timeout = 5
    )

    if ($Request) {
        $Request = '?' + $Request
    }
    $Request = 'https://wttr.in' + $Request

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Encoding", 'deflate, gzip')
    (Invoke-WebRequest -Uri "$Request" -UserAgent "curl" -Headers $headers -UseBasicParsing -TimeoutSec "$Timeout").content
}
