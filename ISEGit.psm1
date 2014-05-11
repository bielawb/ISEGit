$isISE = $host.Name -eq 'Windows PowerShell ISE Host'

if ($isISE) {
    if (-not ($Menu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | 
        Where-Object { $_.DisplayName -eq 'ISEGit' })) {
        $Menu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('ISEGit', $null, $null)
    }
}

function Resolve-ISEPath {
param (
    [switch]$Child
)
    $status = {
        [CmdletBinding()]
        param (
            $Path = '.'
        )
        Push-Location $Path
        git.exe status --porcelain 
        Pop-Location
    }

    if ($psISE.CurrentFile) {
        $FileOpen = $true
        $FilePath = Split-Path $psISE.CurrentFile.FullPath
        $FileName = Split-Path $psISE.CurrentFile.FullPath -Leaf
        & $status -ErrorVariable ScriptPane -ErrorAction SilentlyContinue -Path $FilePath |
            Out-Null
    }


    & $status -ErrorVariable ConsolePane -ErrorAction SilentlyContinue -Path $pwd.ProviderPath |
        Out-Null

    if ($Child) {
        # Start with edited file...
        if ((-not $ScriptPane) -and $FileOpen) {
            New-Object PSObject -Property @{
                Name = $FileName
                Path = $FilePath
            }
        } elseif (-not $ConsolePane) {
            New-Object PSobject -Property @{
                Name = '*'
                Path = $pwd.ProviderPath
            }
        }
    } else {
        if (-not $ConsolePane) {
            New-Object PSObject -Property @{
                Name = '*'
                Path = $pwd.ProviderPath
            }
        } elseif ((-not $ScriptPane) -and $FileOpen) {
            New-Object PSobject -Property @{
                Name = $FileName
                Path = $FilePath
            }
        }

    }
}

function Get-IseInput {
[OutputType('System.String')]
param (
    [string]$Prompt,
    [string]$Title = 'Enter data requested'
)

    # We are in ISE - so WPF is already "there"... ;)
    $XAML = [xml](Get-Content $PSScriptRoot\Input.xaml)
    $Reader = New-Object System.Xml.XmlNodeReader $XAML             
    $Dialog = [Windows.Markup.XamlReader]::Load($Reader)            
    $Dialog.Title = $Title
    foreach ($Name in (            
        Select-Xml '//*/@Name' -Xml $XAML |             
            foreach { $_.Node.Value}            
        )) {            
        New-Variable -Name "Control_$Name" -Value $Dialog.FindName($Name)            
    }
    $Control_Prompt.Text = $Prompt
    $Control_OK.Add_Click({
        Set-Variable -Scope 1 -Name Output -Value $Control_Value.Text
        $Dialog.Close()
    })
    $Control_Cancel.Add_Click({
        $Dialog.Close()
    })

    $Dialog.ShowDialog() | Out-Null
    $Output
}

function Get-ISEGitStatus {
    $Path = (Resolve-IsePath).Path
    if ($Path) {
        Get-GitStatus -Path $Path
    }
}

function Add-GitMenuItem {
param (
    [string]$DisplayName,
    [scriptblock]$ScriptBlock,
    [string]$Key
)

    if (-not ($Menu.Submenus | Where-Object { $_.DisplayName -eq $DisplayName }) -and $isISE) {
        try {
            $Menu.Submenus.Add(
                $DisplayName,
                $ScriptBlock,
                $Key
            )
        } catch {
            $Menu.Submenus.Add(
                $DisplayName,
                $ScriptBlock,
                $null
            )
        }
    }
}

function Add-ISEGitItem {
    $Data  = Resolve-IsePath -Child
    if ($Data.Path) {
        Add-GitItem -Path $Data.Path -Name $Data.Name
    }
}

function Checkpoint-ISEGitProject {
    $Data = Resolve-IsePath -Child
    if ($Data.Path) {
        $Message = Get-IseInput -Prompt (
            'Please enter commit message. File(s): {0} Project: {1}' -f $Data.Name, $Data.Path
        ) -Title 'Commit message required!'
        Checkpoint-GitProject -Path $Data.Path -Name $Data.Name -Message $Message
    } 
}

function New-ISEGitBranch {
    $Path = (Resolve-IsePath).Path
    if ($Path) {
        $Name = Get-IseInput -Title 'Name of branch needed' -Prompt 'Provide the name for new branch'
        if ($Name) {
            New-GitBranch -Name $Name -Path $Path
        }
    }
}

function Get-ISEGitBranch {
    $Path = (Resolve-IsePath).Path
    if ($Path) {
        Get-GitBranch -Name * -Path $Path
    }
}

function Merge-ISEGitBranch {
    $Path = (Resolve-IsePath).Path
    if ($Path) {
        $Name = Get-IseInput -Title 'Name of branch needed' -Prompt 'Provide the name of the branch to merge'
        if ($Name) {
            Merge-GitBranch -Name $Name -Path $Path
        }
    }
}

function Remove-ISEGitBranch {
param ([switch]$Force)
    $Path = (Resolve-IsePath).Path
    if ($Path) {
        $Name = Get-IseInput -Title 'Name of branch needed' -Prompt 'Provide the name of the branch to be removed'
        if ($Name) {
            Remove-GitBranch -Name $Name -Path $Path -Force:$Force
        }
    }
}

function Push-ISEGitProject {
    $Path = (Resolve-IsePath).Path
    if ($Path) {
        Push-GitProject -Path $Path   
    }
}

Add-GitMenuItem -DisplayName Status -ScriptBlock {Get-ISEGitStatus} -Key CTRL+SHIFT+S
Add-GitMenuItem -DisplayName Add -ScriptBlock {Add-ISEGitItem} -Key CTRL+SHIFT+A
Add-GitMenuItem -DisplayName Commit -ScriptBlock {Checkpoint-ISEGitProject} -Key CTRL+SHIFT+C
Add-GitMenuItem -DisplayName 'New branch' -ScriptBlock {New-ISEGitBranch} -Key CTRL+SHIFT+B
Add-GitMenuItem -DisplayName 'Get branches' -ScriptBlock {Get-ISEGitBranch} -Key $null
Add-GitMenuItem -DisplayName 'Merge branch' -ScriptBlock {Merge-ISEGitBranch} -Key $null
Add-GitMenuItem -DisplayName 'Remove branch' -ScriptBlock {Remove-ISEGitBranch} -Key $null
Add-GitMenuItem -DisplayName 'Remove branch (forced)' -ScriptBlock {Remove-ISEGitBranch -Force} -Key $null
Add-GitMenuItem -DisplayName Push -ScriptBlock {Push-ISEGitProject} -Key CTRL+SHIFT+P

Export-ModuleMember -Function * -Alias *