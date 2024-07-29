[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

########################
# Edit these variables #
########################
$Username = "admin" # ID of an IVM administrator
$Password = '' # Password of the IVM administrator
$BaseDomain = "https://10.1.1.1:3780" # Access domain/IP to IVM in format https://<domain>:<port>
$TagName = "EXPOSED" # Name of the tag to add to assets. Case sensitive
########################

$BaseUrl = "$BaseDomain/api/3"
$Credentials = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${Username}:${Password}"))
$TagId = -1

$Headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Basic $Credentials"
}

function SearchAssets($Ip) {
    Write-Host "========== SEARCHING ASSETS IN IVM WITH IP `"$Ip`" =========="
    $Url = "$BaseUrl/assets/search"
    $Data = @{
        filters = @(
            @{
                field = "ip-address"
                operator = "is"
                value = $Ip
            }
        )
        match = "any"
    }
    try {
        $Response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body ($Data | ConvertTo-Json)
    }
    catch {
        Write-Host "Error: $_`n"
        Exit
    }
    $AssetIds = @()
    foreach ($Asset in $Response.resources) {
        Write-Host "Asset ID : $($Asset.id) ; $BaseDomain/asset.jsp?devid=$($Asset.id)"
        $AssetIds += $Asset.id
    }
    return $AssetIds
}

function AssetTags($Method, $AssetId, [int]$TagId = $null) {
    if ($Method -eq "GET") {
        Write-Host "======= PRINTING ASSET TAGS ======="
        $Url = "$BaseUrl/assets/$AssetId/tags"

        try {
            $Response = Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers
        }
        catch {
            Write-Host "Error: $_`n"
            Exit
        }
        
        foreach ($Tag in $Response.resources) {
            Write-Host "$($Tag.name) ; $($Tag.source) ; $($Tag.type)"
        }
        
        return $Response.resources
    } elseif ($Method -eq "PUT") {
        Write-Host "===== ADDING TAG `"$TagName`" TO ASSET ====="
        $Url = "$BaseUrl/assets/$AssetId/tags/$TagId"

        try {
            $Response = Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers
        }
        catch {
            Write-Host "Error: $_`n"
            Exit
        }
    }
}

function SearchTags {
    Write-Host "========== PRINTING TAGS IN IVM =========="
    Write-Host "$BaseDomain/tag/listing.jsp"
    $Url = "$BaseUrl/tags"

    try {
        $Response = Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers
    }
    catch {
        Write-Host "Error: $_`n"
        Exit
    }

    $Tags = @()

    foreach ($Tag in $Response.resources) {
        $Tags += $Tag
    }

    for ($i = 1; $i -le $Response.page.totalPages; $i++) {
        $Url = "$BaseUrl/tags?page=$i"
        
        try {
            $Response = Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers
        }
        catch {
            Write-Host "Error: $_`n"
            Exit
        }

        foreach ($Tag in $Response.resources) {
            $Tags += $Tag
        }
    }

    $Tags = $Tags | Sort-Object -Property id

    foreach ($Tag in $Tags) {
        Write-Host "$($Tag.id) ; $($Tag.name) ; $($Tag.source) ; $($Tag.type)"
    }

    return $Tags
}

function CreateTag {
    Write-Host "===== CREATING TAG `"$TagName`" IN IVM ====="
    $Url = "$BaseUrl/tags"
    $Data = @{
        name = $TagName
        type = "custom"
    }

    try {
        $Response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body ($Data | ConvertTo-Json)
    }
    catch {
        Write-Host "Error: $_`n"
        Exit
    }
    
    return $Response.id
}

function Main {
    param (
        [string]$IpFilePath
    )

    if (-not $IpFilePath) {
        Write-Host "Usage: .\main.ps1 <path_to_ip_file>`n"
        return
    }

    if (-not (Test-Path -Path $IpFilePath)) {
        Write-Host "Usage: .\main.ps1 <path_to_ip_file>`n"
        return
    } else {
        try {
            $IpList = Get-Content -Path $IpFilePath | ForEach-Object { $_.Trim() }
        } catch {
            Write-Host "Unable to open $IpFilePath`n"
            return
        }
    }

    $global:TagId = -1
    $AssetNumber = 0
    foreach ($Ip in $IpList) {
        $AssetIds = SearchAssets -Ip $Ip

        foreach ($AssetId in $AssetIds) {
            $Tags = AssetTags -Method "GET" -AssetId $AssetId
            $Found = $false
            foreach ($Tag in $Tags) {
                if ($Tag.name -eq $TagName) {
                    Write-Host "===== TAG `"$TagName`" ALREADY GIVEN TO ASSET `"$Ip`" / `"$AssetId`"=====`n"
                    $global:TagId = $Tag.id
                    $Found = $true
                    break
                }
            }

            if (-not $Found) {
                if ($global:TagId -eq -1) {
                    $GlobalTags = SearchTags
                    foreach ($Tag in $GlobalTags) {
                        if ($Tag.name -eq $TagName) {
                            $global:TagId = $Tag.id
                            Write-Host "===== FOUND TAG `"$TagName`" IN IVM WITH ID $($global:TagId) ====="
                            Write-Host "$BaseDomain/tag/detail.jsp?tagID=$($global:TagId)"
                            break
                        }
                    }
                }

                if ($global:TagId -eq -1) {
                    $global:TagId = CreateTag
                    Write-Host "$TagName ; $($global:TagId) ; $BaseDomain/tag/detail.jsp?tagID=$($global:TagId)"
                }

                AssetTags -Method "PUT" -AssetId $AssetId -TagId $global:TagId

                Write-Host "======= TAG `"$TagName`" ADDED TO ASSET `"$Ip`" / `"$AssetId`" =======`n"
                $AssetNumber++
            }
        }
    }

    if ($AssetNumber -gt 0) {
        Write-Host "Successfully tagged $AssetNumber assets"
    } else {
        Write-Host "All assets were already tagged"
    }
}

Main -IpFilePath $args[0]
