Function Get-UserInformation {
    [CmdletBinding()]
    param(
        [string]$UserEmail
    )

    begin {
        $diagnosticContext = New-Object 'System.Collections.Generic.List[string]'
        $breadCrumb = 0
    }

    process {

        try {
            $diagnosticContext.Add("Get-UserInformation $($breadCrumb; $breadCrumb++)")
            $mailboxInfo = Get-Mailbox -Identity $UserEmail -ErrorAction Stop
            $mbxGuid = $mailboxInfo.ExchangeGuid.Guid
            $databaseName = $mailboxInfo.Database.ToString()

            $diagnosticContext.Add("Get-UserInformation $($breadCrumb; $breadCrumb++)")
            $mailboxStats = Get-MailboxStatistics -Identity $UserEmail

            $diagnosticContext.Add("Get-UserInformation $($breadCrumb; $breadCrumb++)")
            $dbCopyStatus = Get-MailboxDatabaseCopyStatus $databaseName\* |
                Where-Object {
                    $_.Status -like "*Mounted*"
                }
            $primaryServer = $dbCopyStatus.Name.Substring($dbCopyStatus.Name.IndexOf("\") + 1)

            $diagnosticContext.Add("Get-UserInformation $($breadCrumb; $breadCrumb++)")
            $primaryServerInfo = Get-ExchangeServer -Identity $primaryServer

            if ($primaryServerInfo.AdminDisplayVersion.ToString() -notlike "Version 15.2*") {
                throw "User isn't on an Exchange 2019 server"
            }

            $diagnosticContext.Add("Get-UserInformation $($breadCrumb; $breadCrumb++)")
            $dbStatus = Get-MailboxDatabase -Identity $databaseName -Status

            $diagnosticContext.Add("Get-UserInformation $($breadCrumb; $breadCrumb++)")
        } catch {
            throw "Failed to find '$UserEmail' information. InnerException: $($Error[0].Exception)"
        }
    }
    end {
        return [PSCustomObject]@{
            UserEmail          = $UserEmail
            MailboxGuid        = $mbxGuid
            PrimaryServer      = $primaryServer
            DBWorkerID         = $dbStatus.WorkerProcessId
            Database           = $databaseName
            ExchangeServer     = $primaryServerInfo
            DatabaseStatus     = $dbStatus
            DatabaseCopyStatus = $dbCopyStatus
            MailboxInfo        = $mailboxInfo
            MailboxStatistics  = $mailboxStats
            DiagnosticContext  = $diagnosticContext
        }
    }
}