if (-not ($Menu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | 
    where { $_.DisplayName -eq 'ISEGit' })) {
    $Menu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('ISEGit', $null, $null)
}

if (-not (Get-Alias -Name git -ErrorAction SilentlyContinue)) {
    $GitPath = Resolve-Path -Path $env:USERPROFILE\AppData\Local\GitHub\*\cmd\git.exe
    New-Alias -Name git -Value $GitPath.ProviderPath
}


if (-not ($Menu.Submenus | where { $_.DisplayName -eq 'Status' })) {
    try {
        $Menu.Submenus.Add(
            'Status',
            {Get-GitStatus},
            'CTRL+ALT+S'
        )
    } catch {
        $Menu.Submenus.Add(
            'Status',
            {Get-GitStatus},
            $null
        )
    }
}

if (-not ($Menu.Submenus | where { $_.DisplayName -eq 'Add' })) {
    try {
        $Menu.Submenus.Add(
            'Add',
            {Add-GitItem},
            'CTRL+ALT+A'
        )
    } catch {
        $Menu.Submenus.Add(
            'Add',
            {Add-GitItem},
            $null
        )
    }
}

if (-not ($Menu.Submenus | where { $_.DisplayName -eq 'Commit' })) {
    try {
        $Menu.Submenus.Add(
            'Commit',
            {Checkpoint-GitProject},
            'CTRL+ALT+C'
        )
    } catch {
        $Menu.Submenus.Add(
            'Commit',
            {Checkpoint-GitProject},
            $null
        )
    }
}

Export-ModuleMember -Function * -Alias *