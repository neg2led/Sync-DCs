#Requires -Modules ActiveDirectory

function Sync-DCs {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory = $false,
            Position = 0,
            HelpMessage = "List of Domain Controllers to sync.")]
        [Alias("DCs", "DomainControllers", "DomainControllerList")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $DCList = "All",
        # Number of times to loop repadmin
        [Parameter(Mandatory = $false,
            Position = 1,
            HelpMessage = "Number of times to loop synchronization. Defaults to 3")]
        [int]
        $LoopCount = 3
    )

    if ($DCList -eq "All") {
        # Import AD module
        try {
            Write-Output "All domain controllers specified, getting list from AD"
            Import-Module ActiveDirectory -ErrorAction Stop
            $DCList = (Get-ADDomainController -Filter * -ErrorAction Stop).Name
        } catch {
            Write-Error -Message "Unable to retrieve domain controller list; do you have the AD PowerShell module installed?" -Category NotInstalled -ErrorAction Stop
        }
    }

    Invoke-Command -ComputerName $DCList -ThrottleLimit 4 -ScriptBlock {
        $LoopCount = $Using:LoopCount
        $DCList = $Using:DCList
        [int32]$InstanceID = $DCList.IndexOf($($DCList -match $Env:COMPUTERNAME))
        for ($i = 1; $i -le $Using:LoopCount; $i++) {
            Write-Progress -Id $InstanceID -Activity "Synchronizing $Env:COMPUTERNAME" -Status "Loop $i of $Using:LoopCount" -CurrentOperation "Pushing..." -PercentComplete $(100 / $LoopCount * ($i - 1) + (50 / $LoopCount))
            Start-Process -FilePath "$Env:SystemRoot\system32\repadmin.exe" -ArgumentList "/syncall", "/APedq" -NoNewWindow -Wait
            Start-Sleep -Seconds 3
            Write-Progress -Id $InstanceID -Activity "Synchronizing $Env:COMPUTERNAME" -Status "Loop $i of $Using:LoopCount" -CurrentOperation "Pulling..." -PercentComplete $(100 / $LoopCount * $i)
            Start-Process -FilePath "$Env:SystemRoot\system32\repadmin.exe" -ArgumentList "/syncall", "/Aedq" -NoNewWindow -Wait
            Start-Sleep -Seconds 3
        }
        Write-Progress -Id $InstanceID  -Activity "Synchronizing $Env:COMPUTERNAME" -Status "Complete" -Completed
        Write-Output "Completed sync for $Env:COMPUTERNAME"
    }
    Write-Host "Done!" -ForegroundColor Green
}