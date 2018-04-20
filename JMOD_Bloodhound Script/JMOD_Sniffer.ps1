#networking related, for use in Invoke-Webrequest/RestMethod
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::DnsRefreshTimeout = 0

$netAssembly = [Reflection.Assembly]::GetAssembly([System.Net.Configuration.SettingsSection])

if($netAssembly)
{
    $bindingFlags = [Reflection.BindingFlags] "Static,GetProperty,NonPublic"
    $settingsType = $netAssembly.GetType("System.Net.Configuration.SettingsSectionInternal")

    $instance = $settingsType.InvokeMember("Section", $bindingFlags, $null, $null, @())

    if($instance)
    {
        $bindingFlags = "NonPublic","Instance"
        $useUnsafeHeaderParsingField = $settingsType.GetField("useUnsafeHeaderParsing", $bindingFlags)

        if($useUnsafeHeaderParsingField)
        {
          $useUnsafeHeaderParsingField.SetValue($instance, $true)
        }
    }
}
#end of network related calls

#function get token from reddit to utilize the api
function Get-RedditToken 
{
    $credentials = @{
    grant_type = "password"
    username = $Global:username
    password = $Global:password
    }
    $Global:token = Invoke-RestMethod -Method Post -Uri "https://www.reddit.com/api/v1/access_token" -Body $credentials -ContentType 'application/x-www-form-urlencoded' -Credential $Global:creds
}

#get token from local .txt
    #then check if it's valid, if not use function
$token = $null
try
{
    $token = (Import-Csv -Path "$PSScriptRoot\tokenCache.csv") 
}
catch
{
    Write-Host "Cached token doesn't exist..."
    Get-RedditToken
}

#import local Reddit API cred .csv file
$credFile = Import-Csv -Path "$PSScriptRoot\redditAPILogin.csv"

#load in creds to obscure them
$username = $credFile.redditUser
$password = $credFile.apiRedditBotPass
$clientID = $credFile.clientID
$userAgent = $credFile.userAgent
$clientSecret = ConvertTo-SecureString ($credFile.clientSecret) -AsPlainText -Force
$creds = New-Object -TypeName System.management.Automation.PSCredential -ArgumentList $clientID, $clientSecret
 
#authorization header
$header = @{ 
    authorization = $token.token_type + " " + $token.access_token
    }

#check if cached token is valid
try
{
    Invoke-RestMethod -uri "https://oauth.reddit.com/user/$username" -Headers $header -UserAgent $userAgent
}
catch
{
    Write-Host "Token expired, renewing..." -ForegroundColor Red
    Get-RedditToken #updates token value
    $header = @{ 
    authorization = $token.token_type + " " + $token.access_token
    }
    Write-Host "Renewed Access Code." -ForegroundColor Green
}

#TO-DO: Remove everything above this, this powershell script will only be used to sniff any untracked hot posts with JMOD reply

#have a search limit of the latest 100 posts on the 2007scape reddit
$payload = @{
            limit = '100'
            }

#attempt to search the new posts, if fails reattempt to get token (as it may have expired)
    #TO DO: rewrite this for smarter error checking, but in most cases it will be the token expiring
    #since the script is running once per minute to check against new posts (and there doesn't seem to be a way to check when a token will expire other than tracking it yourself)
        #we'll just do a lazy try-catch for each API call

$searchBlock = $null
try
{
    $searchBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/r/2007scape/hot" -Method Get -Headers $header -Body $payload -UserAgent $userAgent
}
catch
{
    Write-Host "Token expired, renewing..." -ForegroundColor Red
    Get-RedditToken #updates token value
    $header = @{ 
    authorization = $token.token_type + " " + $token.access_token
    }
    Write-Host "Renewed Access Code." -ForegroundColor Green
    
    $searchBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/r/2007scape/hot" -Method Get -Headers $header -Body $payload -UserAgent $userAgent
}

#go through each news post with a J-MOD reply flair
foreach($newsLink in ($searchBlock.data.children.data | Where {$_.link_flair_text -match "J-MOD"}))
{
    $snifferSummaryPost = ""
    $permaLinksList = New-Object System.Collections.Generic.List[System.Object]

    $postSavedStatus = $_.saved
    $postID = $newsLink.id
    $sniffedPostUri = "https://oauth.reddit.com/r/2007scape/comments/$postID"

    #get the interior post information (comments)
    try
    {
        $postInfo = Invoke-RestMethod -uri $sniffedPostUri -Method GET -Headers $header -UserAgent $userAgent
    }
    catch
    {
        Write-Host "Token expired, renewing..." -ForegroundColor Red
        Get-RedditToken #updates token value
        $header = @{ 
        authorization = $token.token_type + " " + $token.access_token
        }
        Write-Host "Renewed Access Code." -ForegroundColor Green
    
        $postInfo = Invoke-RestMethod -uri $sniffedPostUri -Method GET -Headers $header -UserAgent $userAgent
    }

    #foreach comment in the post with a jagexmod flair
    foreach($comment in ($postInfo.data.children | Where {$_.kind -eq "t1"}).data | Where {$_.saved -eq $false -and ($_.author_flair_css_class -match "jagexmod")})
    {
        $payload = @{
                    category = "cached"
                    id = $comment.name

                    }

        $permaLinksList.Add([pscustomobject]@{'Author' = $comment.author
                    'Permalink' = $comment.permalink})

        #save this comment, so we can avoid finding it in later searches
        try
        {
            $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $header -Body $payload -UserAgent $userAgent
        }
        catch
        {
            Write-Host "Token expired, renewing..." -ForegroundColor Red
            Get-RedditToken #updates token value
            $header = @{ 
            authorization = $token.token_type + " " + $token.access_token
            }
            Write-Host "Renewed Access Code." -ForegroundColor Green
    
            $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $header -Body $payload -UserAgent $userAgent
        }
    }

    if($permaLinksList)
    {
        if($postSavedStatus)
        {
            #script has touched this post before, append commments to previous post
            #TO-DO: implement logic to update previous posts
        }
        else
        {
            #post not saved, create new text post
            $parsedText = ""
            foreach($jmodComment in $permaLinksList)
            {
                
            }
            $parsedText += "`n`n&nbsp;`n`n---`n`nHi, I'm your friendly neighborhood OSRS bloodhound.  `nI tried my best to find all the JMOD's comments in this post.`nInterested to see how I work? See my post [here](https://www.google.com) for my GitHub repo!"

            $payload = @{
            api_type = "json"
            text = $parsedText
            thing_id= $targetID
            }

            try
            {
                $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent $userAgent
            }
            catch
            {
                Write-Host "Token expired, renewing..." -ForegroundColor Red
                Get-RedditToken #updates token value
                $header = @{ 
                authorization = $token.token_type + " " + $token.access_token
                }
                Write-Host "Renewed Access Code." -ForegroundColor Green
    
                $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent $userAgent
            }


            #save post
            $payload = @{
                category = "cached"
                id = $commentID
            }

            #save POST
            try
            {
                $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $header -Body $payload -UserAgent $userAgent
            }
            catch
            {
                Write-Host "Token expired, renewing..." -ForegroundColor Red
                Get-RedditToken #updates token value
                $header = @{ 
                authorization = $token.token_type + " " + $token.access_token
                }
                Write-Host "Renewed Access Code." -ForegroundColor Green
    
                $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $header -Body $payload -UserAgent $userAgent
            }
        }
    }
    break
}


#export latest token to local csv file
$token | Export-Csv -Path "$PSScriptRoot\tokenCache.csv" -NoTypeInformation