# Domain Name with dot in the end
$DomainName = 'mydomain.com.br.'

# Subdomain - Record Set Name without Domain
$Subdomain = 'test'

# Record Set Type (A, CNAME)
$RecordType = 'A'

# Server Name - Used to ensure Route 53 is not changed if a new server is created based on the same AMI
$ServerName = 'EC2AMAZ-C908EB9'




############## START POWERSHELL SCRIPT ###################
$HostName = hostname

If($HostName -eq $ServerName)
{
    # Create the FQDN
    If($Subdomain)
    {
        $FQDN = @($Subdomain, $DomainName) -join '.'
    }
    Else
    {
        $FQDN = $DomainName
    }

    # Get the Hosted Zone
    $Zone = Get-R53HostedZones | Where-Object {$_.Name -eq $DomainName}
    If($Zone)
    {
        # Get the resource record sets for this zone, taking care to pull as many records as there are in the zone.
        $ResourceRecords = Get-R53ResourceRecordSet -HostedZoneId $Zone.Id -MaxItem $Zone.ResourceRecordSetCount | % {$_.ResourceRecordSets}
        $Record = $ResourceRecords | Where-Object {$_.Name -eq $FQDN -AND $_.Type -eq $RecordType}
        # Get your public IP
        $PublicIP = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip
        Write-Host ("Checking public IP against resource record.")
        If($Record.ResourceRecords[0].Value -ne $PublicIP)
        {
            Write-Host ("Public IP {0} != {1}" -f $PublicIP, $Record.ResourceRecords[0].Value)
            # Create the new ResourceRecordSet
            $UpdatedResourceRecord = New-Object Amazon.Route53.Model.ResourceRecordSet
            $UpdatedResourceRecord.Name = $FQDN
            $UpdatedResourceRecord.Type = $RecordType
            # Set the resource record using the public IP
            $UpdatedResourceRecord.ResourceRecords = (New-Object Amazon.Route53.Model.ResourceRecord($PublicIP))
            $UpdatedResourceRecord.TTL = ($Record.TTL)
            # Create the R53 change action
            $Change = New-Object Amazon.Route53.Model.Change
            $Change.Action = [Amazon.Route53.ChangeAction]::UPSERT
            $Change.ResourceRecordSet = $UpdatedResourceRecord
            # Push the change up
            $ChangeBatch = Edit-R53ResourceRecordSet -HostedZoneId $Zone.Id -ChangeBatch_Change $Change
            Write-Host ("Change filed at {0} with ID {1} against {2}" -f $ChangeBatch.SubmittedAt, $ChangeBatch.Id, $FQDN)
        }
        Else
        {
            Write-Host ("IPs match. No changes")
        }
    }
    Else
    {
        throw("Unable to locate hosted zone for domain {0}" -f $DomainName)
    }
}
Else
{
    throw("Script was ignored because the hostname {0} is not valid" -f $ServerName)
}