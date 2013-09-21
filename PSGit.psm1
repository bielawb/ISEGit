if (-not (Get-Alias -Name git -ErrorAction SilentlyContinue)) {
    $GitPath = Resolve-Path -Path $env:USERPROFILE\AppData\Local\GitHub\*\cmd\git.exe
    New-Alias -Name git -Value $GitPath.ProviderPath
}

function Get-GitStatus {
param (
    [ValidateScript({
        if (Test-Path -Path $_) {
            $true
        } else {
            throw 'Provide a path to existing directory'
        }
    })]
    [string]$Path = '.'
)
    $status = {
        [CmdletBinding()]
        param (
            $Path = '.'
        )
        Push-Location $Path
        git status --porcelain 
        Pop-Location
    }

    function Convert-StatusToObject {
    param (
        [Parameter(
            ValueFromPipeline = $true
        )]
        [string]$StatusLine
    )
    begin {
        $clean = $true
    } 
    
    process {
        if ($StatusLine) {
            $clean = $false
            if ($StatusLine -match '^(?<Index>.)(?<WorkTree>.)\s(?<FileName>.*)$') {
                $Matches.Remove(0)
                New-Object PSObject -Property $Matches
            }
        }
    } 
    
    end {
        if ($clean) {
            Write-Warning "Directory $Path clean or not a git repository"
        }
    }
    }


    & $status -Path $Path -ErrorAction SilentlyContinue -ErrorVariable GettingStatus |
        Convert-StatusToObject
    if ($GettingStatus) {
    @'
Couldn't check status for {0}: "{1}"
'@ -f $Path, $BoundPath[0].Exception.Message | Write-Warning
    }
}

function Add-GitItem {
[CmdletBinding(
    DefaultParameterSetName = 'byName'
)]
param (
    [Parameter(
        ParameterSetName = 'byName',
        Mandatory = $true
    )]
    [string]$Name,
    [ValidateScript({
        if (Test-Path -Path $_) {
            $true
        } else {
            throw 'Provide a path to existing directory'
        }
    })]
    [string]$Path,
    [Parameter(
        ParameterSetName = 'all'
    )]
    [switch]$All
)

    $add = {
        [CmdletBinding()]
        param (
            $Path = '.',
            $Name,
            [switch]$All
        )
        Push-Location $Path
        if ($All) {
            git add -A $Name
        } else {
            git add $Name
        }
        Pop-Location
    }

    if ($Name) {
        & $add -Name $Name -Path $Path -ErrorVariable Adding -ErrorAction SilentlyContinue
    } else {
        & $add -All -Path $Path -ErrorVariable Adding -ErrorAction SilentlyContinue
    }

    if ($Adding) {
        if ($All) {
            $Name = '*'
        }
        @'
Couldn't add file(s): {0} to {1}: "{2}"
'@ -f $Name, $Path, $Adding[0].Exception.Message | Write-Warning
    }

}

function Checkpoint-GitProject {
[CmdletBinding(
    DefaultParameterSetName = 'byName'
)]
param (
    [Parameter(
        ParameterSetName = 'byName',
        Mandatory = $true,
        Position = 0
    )]
    [string]$Name,
    [ValidateScript({
        if (Test-Path -Path $_) {
            $true
        } else {
            throw 'Provide a path to existing directory'
        }
    })]
    [string]$Path,
    [Parameter(
        ParameterSetName = 'all'
    )]
    [switch]$All,
    [Parameter(
        ValueFromRemainingArguments = $true,
        Position = 1
        
    )]
    $Message
)

    $commit = {
        [CmdletBinding()]
        param (
            $Path = '.',
            $Name,
            [switch]$All,
            [string]$Message
        )
        Push-Location $Path
        if ($All) {
            git commit -a -m $Message
        } else {
            git commit $Name -m $Message
        }
        Pop-Location
    }

    if (!$Message) {
        Write-Warning "Need a message to commit!"
        return
    }

    if ($Name) {
        & $commit -Name $Name -Path $Path -Message $Message -ErrorVariable Commiting -ErrorAction SilentlyContinue
    } else {
        & $commit -All -Path $Path -Message $Message -ErrorVariable Commiting -ErrorAction SilentlyContinue
    }

    if ($Commiting) {
        if ($All) {
            $Name = '*'
        }
        @'
Couldn't add file(s): {0} to {1}: "{2}"
'@ -f $Name, $Path, $Commiting[0].Exception.Message | Write-Warning
    }
}

function New-GitBranch {
param (
    [ValidateScript({
        if (Test-Path -Path $_) {
            $true
        } else {
            throw 'Provide a path to existing directory'
        }
    })]
    [string]$Path,
    [Parameter(
        Mandatory = $true
    )]
    [string]$Name
)

    $newbranch = {
        [CmdletBinding()]
        param (
            $Path = '.',
            $Name
        )
        Push-Location $Path
        git branch $Name
        Pop-Location
    }

    & $newbranch -Name $Name -Path $Path -ErrorVariable CreatingBranch -ErrorAction SilentlyContinue

    if ($CreatingBranch) {
        @'
Couldn't create new branch: {0} in {1}: "{2}"
'@ -f $Name, $Path, $CreatingBranch[0].Exception.Message | Write-Warning
    }
}



New-Alias -Name Commit-GitProject -Value Checkpoint-GitProject

Export-ModuleMember -Function * -Alias *