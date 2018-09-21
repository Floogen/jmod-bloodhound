import praw

reddit = praw.Reddit('JMOD_Bloodhound', user_agent='User Agent - JMOD_Bloodhound PS Script')

subreddit = reddit.subreddit('redditdev')
print(subreddit.display_name)
print(subreddit.title)
