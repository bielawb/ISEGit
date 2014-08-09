$cmdPath = (Resolve-Path -Path $env:USERPROFILE\AppData\Local\GitHub\*\cmd).ProviderPath
$binPath = (Resolve-Path -Path $env:USERPROFILE\AppData\Local\GitHub\*\bin).ProviderPath
$gitHubPath = (Resolve-Path -Path $env:USERPROFILE\AppData\Local\Apps\*\*\*\gith*\github.exe |
        Sort-Object { (Get-Item $_.ProviderPath).VersionInfo.FileVersion } -Descending |
        Select-Object -First 1).ProviderPath | Split-Path
$poshGitModulePath = (Resolve-Path -Path $env:USERPROFILE\AppData\Local\GitHub\PoshGit_*\posh-git.psm1).ProviderPath

Import-Module -Name $poshGitModulePath -Prefix v2

function Write-GitPrompt {
    Write-v2GitStatus (Get-v2GitStatus)
}

$env:Path = "$cmdPath;$binPath;$gitHubPath;$env:Path"

function Get-GitStatus {
[OutputType('Git.Status')]
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
                New-Object PSObject -Property $Matches | ForEach-Object {
                    $_.PSTypeNames.Insert(0,'Git.Status')
                    $_
                }
            }
        }
    } 
    
    end {
        if ($clean) {
            Write-Warning "Directory $Path clean or not a git repository"
        }
    }
    }


    & $status -Path $Path -ErrorAction SilentlyContinue -ErrorVariable gettingStatus |
        Convert-StatusToObject
    if ($gettingStatus) {
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
        & $add -Name $Name -Path $Path -ErrorVariable adding -ErrorAction SilentlyContinue
    } else {
        & $add -All -Path $Path -ErrorVariable adding -ErrorAction SilentlyContinue
    }

    if ($adding) {
        if ($All) {
            $Name = '*'
        }
        @'
Couldn't add file(s): {0} to {1}: "{2}"
'@ -f $Name, $Path, $adding[0].Exception.Message | Write-Warning
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
        Write-Warning 'Need a message to commit!'
        return
    }

    if ($Name) {
        & $commit -Name $Name -Path $Path -Message $Message -ErrorVariable commiting -ErrorAction SilentlyContinue
    } else {
        & $commit -All -Path $Path -Message $Message -ErrorVariable commiting -ErrorAction SilentlyContinue
    }

    if ($commiting) {
        if ($All) {
            $Name = '*'
        }
        @'
Couldn't add file(s): {0} to {1}: "{2}"
'@ -f $Name, $Path, $commiting[0].Exception.Message | Write-Warning
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
    [string]$Name,
    [switch]$CheckOut
)

    $newbranch = {
        [CmdletBinding()]
        param (
            $Path = '.',
            $Name,
            [switch]$CheckOut
        )
        Push-Location $Path
        git branch $Name
        if ($CheckOut) {
            git checkout $Name
        }
        Pop-Location
    }

    & $newbranch -Name $Name -Path $Path -ErrorVariable creatingBranch -ErrorAction SilentlyContinue -CheckOut:$CheckOut

    if ($creatingBranch) {
        @'
Couldn't create new branch: {0} in {1}: "{2}"
'@ -f $Name, $Path, $creatingBranch[0].Exception.Message | Write-Warning
    }
}

function Get-GitBranch {
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
    $getbranch = {
        [CmdletBinding()]
        param (
            $Path = '.',
            $Name
        )
        Push-Location $Path
        git branch -a --list $Name
        Pop-Location
    }

    & $getbranch -Name $Name -Path $Path -ErrorVariable gettingBranch -ErrorAction SilentlyContinue

    if ($gettingBranch) {
        @'
Couldn't find branch: {0} in {1}: "{2}"
'@ -f $Name, $Path, $gettingBranch[0].Exception.Message | Write-Warning
    }
}

function Merge-GitBranch {
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

    $mergebranch = {
        [CmdletBinding()]
        param (
            $Path = '.',
            $Name
        )
        Push-Location $Path
        git merge $Name
        Pop-Location
    }

    & $mergebranch -Name $Name -Path $Path -ErrorVariable mergingBranch -ErrorAction SilentlyContinue

    if ($mergingBranch) {
        @'
Couldn't merge branch: {0} in {1}: "{2}"
'@ -f $Name, $Path, $mergingBranch[0].Exception.Message | Write-Warning
    }
}

function Remove-GitBranch {
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
    [string]$Name,
    [switch]$Force
)

    $removebranch = {
        [CmdletBinding()]
        param (
            $Path = '.',
            $Name,
            [switch]$Force
        )

        if ($Force) {
            $option = '-D'
        } else {
            $option = '-d'
        }

        Push-Location $Path
        git branch $Name $option
        Pop-Location
    }

    & $removebranch -Name $Name -Path $Path -ErrorVariable removingBranch -ErrorAction SilentlyContinue -Force:$Force

    if ($removingBranch) {
        @'
Couldn't remove branch: {0} in {1}: "{2}"
'@ -f $Name, $Path, $removingBranch[0].Exception.Message | Write-Warning
    }
}

function Push-GitProject {
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

    $pushProject = {
        [CmdletBinding()]
        param (
            $Path = '.'
        )
        Push-Location $Path
        git push --quiet --porcelain
        Pop-Location
    }

    & $pushProject -Path $Path -ErrorVariable pushingProject -ErrorAction SilentlyContinue

    if ($pushingProject) {
        @'
Couldn't push project {1}: "{2}"
'@ -f $Path, $pushingProject[0].Exception.Message | Write-Warning
    }
}

New-Alias -Name Commit-GitProject -Value Checkpoint-GitProject

Export-ModuleMember -Function *-Git* -Alias *