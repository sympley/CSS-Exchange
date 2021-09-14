﻿# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

. $PSScriptRoot\SetupLogReviewerFunctions.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Test-ExpiredCertificate.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Test-IsHybridObjectFoundOnPremises.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Test-KnownIssuesByErrors.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Test-KnownLdifErrors.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Test-KnownMsiIssuesCheck.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Test-KnownOrganizationPreparationErrors.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Test-PrerequisiteCheck.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Write-LastErrorInformation.ps1
. $PSScriptRoot\..\SetupLogReviewer\Checks\Write-Result.ps1
Function Invoke-SetupLogReviewer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            Position = 0)]
        [System.IO.FileInfo]$SetupLog,
        [switch]$DelegatedSetup
    )
    Function InvokeTests {
        [CmdletBinding()]
        param(
            [object]$SetupLogReviewer,
            [string[]]$Tests
        )

        foreach ($test in $Tests) {
            $result = $SetupLogReviewer | & $test

            if ($null -ne $result) {
                $result | Write-Result
                break
            }
        }
    }

    if (-not ([IO.File]::Exists($SetupLog))) {
        Write-Error "Could not find file: $SetupLog"
        return
    }

    $setupLogReviewer = Get-SetupLogReviewer -SetupLog $SetupLog
    $color = "Gray"
    $ranDate = $setupLogReviewer.SetupRunDate

    if ($ranDate -lt ([DateTime]::Now.AddDays(-14))) { $color = "Yellow" }
    Write-Host "Setup.exe Run Date: $ranDate" -ForegroundColor $color
    Write-Host "Setup.exe Build Number: $($setupLogReviewer.SetupBuildNumber)"

    if (-not ([string]::IsNullOrEmpty($setupLogReviewer.LocalBuildNumber))) {
        Write-Host "Current Exchange Build: $($setupLogReviewer.LocalBuildNumber)"

        if ($setupLogReviewer.LocalBuildNumber -eq $setupLogReviewer.SetupBuildNumber) {
            Write-Host "Same build number detected..... if using powershell.exe to start setup. Make sure you do '.\setup.exe'" -ForegroundColor "Red"
        }
    }

    $successFullInstall = $setupLogReviewer | SelectStringLastRunOfExchangeSetup -Pattern "The Exchange Server setup operation completed successfully\."

    if ($null -ne $successFullInstall) {
        Write-Host "The most recent setup attempt completed successfully based off this line:"
        Write-Host $successFullInstall.Line
        Write-Host "`r`nNo Action is required."
        return
    }

    if ($DelegatedSetup) {
        $setupLogReviewer | Test-DelegatedInstallerHasProperRights
        return
    }

    InvokeTests -SetupLogReviewer $setupLogReviewer -Tests @(
        "Test-PrerequisiteCheck",
        "Test-KnownLdifErrors",
        "Test-KnownOrganizationPreparationErrors",
        "Test-KnownMsiIssuesCheck",
        "Test-KnownIssuesByErrors",
        "Test-ExpiredCertificate",
        "Test-IsHybridObjectFoundOnPremises",
        "Write-LastErrorInformation"
    )
}
