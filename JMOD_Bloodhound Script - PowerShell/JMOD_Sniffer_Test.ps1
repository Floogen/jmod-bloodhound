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
#TO-DO: Implement karma/J-MOD comment count for bot's trigger to post a comment (use $postInfo.data.children.data.score) < -10?

#end of network related calls

$permaLinksList = New-Object System.Collections.Generic.List[System.Object]

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

function PostConditionCheck($jmodComments)
{
    if($jmodComments.Count -gt 1)
    {
        #see if comment count is greater than 1 for J-MOD comments
        return $true
    }
    else
    {
        foreach($comment in $jmodComments)
        {
            if(([int]$comment.CommentScore) -le -15)
            {
                #if score is less than or equal to -15, trigger bot
                return $true
            }
        }
    }

    #no conditions reached, returning false for trigger
    return $false
}

#function to search sub-tree comments
function SearchSubComments($commentList)
{
    foreach($subComment in $commentList)
    {
        #if there are more replies underneath this subcomment, recursively search downwards
        if($subComment.replies)
        {
            SearchSubComments -commentList $subComment.replies.data.children.data
        }

        #if comment flair matches our target(s), proceed
        if($subComment.author_flair_css_class -match "jagexmod" -or $subComment.author_flair_css_class -match "modmatk" -or $subComment.author_flair_css_class -match "mod-jagex")
        {
            $payload = @{
            category = "cached"
            id = $subComment.name}

                $rawCommentBody = ($subComment.body -split "`n")[0]

                if($rawCommentBody.Length -gt 45)
                {
                    #cut it off with ...
                    $rawCommentBody = $rawCommentBody.Substring(0,45) + "..."
                }
                else
                {
                    $rawCommentBody += "..."
                }

                if($rawCommentBody -eq "")
                {
                    $rawCommentBody = "No text found!"
                }
            
            #creating context for the comments if needed
            $commentContext = ""
            if($subComment.depth -gt 0)
            {
                #comment depth is greater than 3, add some context to it
                if($subComment.depth -gt 3)
                {
                    #limit is greater than 3, cap it
                    $commentContext = "?context=3"
                }
                else
                {
                    $commentContext = "?context=" + $subComment.depth
                }
            }

            $global:permaLinksList.Add([pscustomobject]@{'Author' = $subComment.author
            'Title' = $subComment.author_flair_text
            'Permalink' = $subComment.permalink + $commentContext
            'CommentBody' = $rawCommentBody
            'CommentScore' = $subComment.score})

            #if comment is not saved, then save it
            if($subComment.saved -eq $false)
            {
                try
                {
                    $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $global:header -Body $payload -UserAgent $global:userAgent
                }
                catch
                {
                    Write-Host "Token expired, renewing..." -ForegroundColor Red
                    Get-RedditToken #updates token value
                    $header = @{ 
                    authorization = $global:token.token_type + " " + $global:token.access_token
                    }
                    Write-Host "Renewed Access Code." -ForegroundColor Green

                    $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $global:header -Body $payload -UserAgent $global:userAgent
                }
            }
        }
    }
}

#get token from local .csv
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

#uri to get all the comments from the post
        $sniffedPostUri = "https://oauth.reddit.com/r/2007scape/comments/8lrgud"

        #get the post's interior information (comments)
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

#export latest token to local csv file
$token | Export-Csv -Path "$PSScriptRoot\tokenCache.csv" -NoTypeInformation