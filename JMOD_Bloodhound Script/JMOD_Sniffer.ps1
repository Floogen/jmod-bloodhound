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

    $postSavedStatus = $newsLink.saved
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

    #if post was previously touched
    if($postSavedStatus)
    {
        #foreach comment in the post with a jagexmod flair
        foreach($comment in ($postInfo.data.children | Where {$_.kind -eq "t1"}).data | Where {($_.author_flair_css_class -match "jagexmod")})
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
    }
    else
    {
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
    }

    #if any comments were saved, proceed
    if($permaLinksList)
    {
        #sort all linked comments by authors
        $permaLinksList = $permaLinksList | Sort-Object -Property Author
        $parsedText = "Hello there, below is a list of comments made by J-Mods in this thread:`n`n"
        $lastAuthor = ""
        $commentCounter = 1

        if($postSavedStatus)
        {
            #script has touched this post before, append commments to previous post
                #look for bot's previous comment on this post (which will be saved from previous runs)

            #TO-DO: DO based on csv storage rather than searching again, will need to implement cleanup so CSV doesn't build up over time
            $previousPostID = $null
            $previousPostID = "t1_dxp39nh"#TO-DO:DELETE THIS
            foreach($comment in ($postInfo.data.children | Where {$_.kind -eq "t1"}).data | Where {$_.saved -eq $true -and $_.author -eq $username.ToLower()})
            {
                $previousPostID = $comment.name
            }
            
            #found our bot's post
            if($previousPostID)
            {
                foreach($jmodComment in $permaLinksList)
                {
                    if($lastAuthor = "")
                    {
                        $parsedText += "**"+$jmodComment.Author+":**`n`n[Comment $commentCounter](https://www.reddit.com/" + $jmodComment.Permalink +")`n"
                        $lastAuthor = $jmodComment.Author
                    }
                    elseif($lastAuthor -ne $jmodComment.Author)
                    {
                        $commentCounter = 1
                        $parsedText += "`n`n**"+$jmodComment.Author+":**`n`n[Comment $commentCounter](https://www.reddit.com/" + $jmodComment.Permalink +")`n"
                        $lastAuthor = $jmodComment.Author
                    }
                    else
                    {
                        #iterate comment counter by one, then append the comment
                        $commentCounter += 1
                        $parsedText += "[Comment $commentCounter](www.reddit.com/" + $jmodComment.Permalink +")`n"
                    }
                }
                #append marker to end of post
                $editTime = (Get-Date)
                $parsedText += "`n`nLast edited: $editTime`n`n&nbsp;`n`n---`n`nHi, I'm your friendly neighborhood OSRS bot.  `nI tried my best to find all the J-Mod's comments in this post.`n`nInterested to see how I work? See my post [here](https://www.google.com) for my GitHub repo!"

                $payload = @{
                api_type = "json"
                text = $parsedText
                thing_id= $previousPostID
                }

                #edit post
                Write-Host "Editing post... $previousPostID"
                try
                {
                    Invoke-RestMethod -uri "https://oauth.reddit.com/api/editusertext" -Method Post -Headers $header -Body $payload -UserAgent $userAgent
                }
                catch
                {
                    Write-Host "Token expired, renewing..." -ForegroundColor Red
                    Get-RedditToken #updates token value
                    $header = @{ 
                    authorization = $token.token_type + " " + $token.access_token
                    }
                    Write-Host "Renewed Access Code." -ForegroundColor Green
                    Invoke-RestMethod -uri "https://oauth.reddit.com/api/editusertext" -Method Post -Headers $header -Body $payload -UserAgent $userAgent
                }
            }
        }
        else
        {
            #post not saved, create new text post
            foreach($jmodComment in $permaLinksList)
            {
                if($lastAuthor = "")
                {
                    $parsedText += "**"+$jmodComment.Author+":**`n`n[Comment $commentCounter](https://www.reddit.com/" + $jmodComment.Permalink +")`n"
                    $lastAuthor = $jmodComment.Author
                }
                elseif($lastAuthor -ne $jmodComment.Author)
                {
                    $commentCounter = 1
                    $parsedText += "`n`n**"+$jmodComment.Author+":**`n`n[Comment $commentCounter](https://www.reddit.com/" + $jmodComment.Permalink +")`n"
                    $lastAuthor = $jmodComment.Author
                }
                else
                {
                    #iterate comment counter by one, then append the comment
                    $commentCounter += 1
                    $parsedText += "[Comment $commentCounter](www.reddit.com/" + $jmodComment.Permalink +")`n"
                }
            }
            #append marker to end of post
            $parsedText += "`n`n&nbsp;`n`n---`n`nHi, I'm your friendly neighborhood OSRS bot.  `nI tried my best to find all the J-Mod's comments in this post.`n`nInterested to see how I work? See my post [here](https://www.google.com) for my GitHub repo!"

            $payload = @{
            api_type = "json"
            text = $parsedText
            thing_id= "t3_8dq691"#TO-DO: UNCOMMENT THIS/REMOVE FORMER PART: $postID
            }

            #comment on the post now
            try
            {
                $houndPost = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent $userAgent
            }
            catch
            {
                Write-Host "Token expired, renewing..." -ForegroundColor Red
                Get-RedditToken #updates token value
                $header = @{ 
                authorization = $token.token_type + " " + $token.access_token
                }
                Write-Host "Renewed Access Code." -ForegroundColor Green
    
                $houndPost = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent $userAgent
            }


            #save newly posted comment
            $payload = @{
                category = "cached"
                id = $houndPost.json.data.things.data.name
            }

            #save bot's posted comment
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

    if(!$postSavedStatus)      
    { 
        Write-Host "Caching and posting to" $newsLink.title
        $payload = @{
                    category = "cached"
                    id = $newsLink.name

                    }
        try
        {
            $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $header -Body $payload -UserAgent $userAgent
        }
        catch
        {
            Write-Host "Token expired, renewing..." -ForegroundColor Red
            Get-RedditToken #updates token value
            $header = @{ 
            authorization = $token.token_type + " " + $token.access_token}
        }
        Write-Host "Renewed Access Code." -ForegroundColor Green
        
        $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $header -Body $payload -UserAgent $userAgent
    }
    break
}


#export latest token to local csv file
$token | Export-Csv -Path "$PSScriptRoot\tokenCache.csv" -NoTypeInformation