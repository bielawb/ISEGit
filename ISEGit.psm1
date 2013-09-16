if (-not ($Menu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | 
    where { $_.DisplayName -eq 'ISEGit' })) {
    $Menu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('ISEGit', $null, $null)
}

if (-not (Get-Alias -Name git -ErrorAction SilentlyContinue)) {
    $GitPath = Resolve-Path -Path $env:USERPROFILE\AppData\Local\GitHub\*\cmd\git.exe
    New-Alias -Name git -Value $GitPath.ProviderPath
}

function Resolve-IsePath {
param (
    [switch]$Child
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
    [string]$Title = "Enter data requested"
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

function Add-ISEGitItem {
    $Data  = Resolve-IsePath -Child
    if ($Data.Path) {
        Add-GitItem -Path $Data.Path -Name $Data.Name
    }
}

function Checkpoint-ISEGitProject {
    $Data = Resolve-IsePath -Child
    $Message = Get-IseInput -Prompt (
        "Please enter commit message. File(s): {0} Project: {1}" -f $Data.Name, $Data.Path
    ) -Title "Commit message required!"
    if ($Data.Path) {
        Checkpoint-GitProject -Path $Data.Path -Name $Data.Name -Message $Message
    } 
}

if (-not ($Menu.Submenus | where { $_.DisplayName -eq 'Status' })) {
    try {
        $Menu.Submenus.Add(
            'Status',
            {Get-ISEGitStatus},
            'CTRL+SHIFT+S'
        )
    } catch {
        $Menu.Submenus.Add(
            'Status',
            {Get-ISEGitStatus},
            $null
        )
    }
}

if (-not ($Menu.Submenus | where { $_.DisplayName -eq 'Add' })) {
    try {
        $Menu.Submenus.Add(
            'Add',
            {Add-ISEGitItem},
            'CTRL+SHIFT+A'
        )
    } catch {
        $Menu.Submenus.Add(
            'Add',
            {Add-ISEGitItem},
            $null
        )
    }
}

if (-not ($Menu.Submenus | where { $_.DisplayName -eq 'Commit' })) {
    try {
        $Menu.Submenus.Add(
            'Commit',
            {Checkpoint-ISEGitProject},
            'CTRL+SHIFT+C'
        )
    } catch {
        $Menu.Submenus.Add(
            'Commit',
            {Checkpoint-ISEGitProject},
            $null
        )
    }
}

Export-ModuleMember -Function * -Alias *