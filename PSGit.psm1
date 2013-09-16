function Get-GitStatus {
param (
    [ValidateScript({
        if (Test-Path -Path $_) {
            $true
        } else {
            throw 'Provide a path to existing directory'
        }
    })]
    [string]$Path
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


    if (!$Path) {
        # Either PWD...
        & $status -Path $PWD.ProviderPath -ErrorAction SilentlyContinue -ErrorVariable PWDFailed |
            Convert-StatusToObject
        if ($PWDFailed) {
            # ...or currently edited file...
            if ($psISE.CurrentFile) {
                & $status -Path (
                    Split-Path $psISE.CurrentFile.FullPath
                ) -ErrorAction SilentlyContinue -ErrorVariable CurrentFailed |
                    Convert-StatusToObject
            } else {
                $CurrentFailed = @(
                    New-Object PSObject -Property @{
                        Exception = New-Object PSObject -Property @{
                            Message = "Couldn't find any open file in current tab"
                        }
                    }
                )
            }
        } 
        
        if ($CurrentFailed) {
            @'
Couldn't check status for:
-- current folder: "{0}"
-- currently edited file: "{1}"
'@ -f $PWDFailed[0].Exception.Message, $CurrentFailed[0].Exception.Message | Write-Warning
        }
         
    } else {
        & $status -Path $Path -ErrorAction SilentlyContinue -ErrorVariable BoundPath |
            Convert-StatusToObject
        if ($BoundPath) {
                    @'
Couldn't check status for {0}: "{1}"
'@ -f $Path, $BoundPath[0].Exception.Message | Write-Warning
        }
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
        & $add -Name $Name -Path $Path
    } else {
        & $add -All -Path $Path
    }
}

function Checkpoint-GitProject {

}

New-Alias -Name Commit-GitProject -Value Checkpoint-GitProject
