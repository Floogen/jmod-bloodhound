# JMOD_Bloodhound
[Reddit Bot] **Powershell** script that actively checks r/2007scape/ for posts with JMOD replies and links them within the specified post.

# How It Works
1. The script is scheduled to check [/r/2007scape/](https://www.reddit.com/r/2007scape/new) every minute for top 100 hot posts with JMOD replies.
2. After finding a match, the script caches the post's ID locally under "activelyWatched.csv", as well as with the timestamp of the latest JMOD reply.
5. After 24 hours, the script caches the actively watched post via Reddit's save function (the script will then ignore it in future passes, as it ignores all saved posts).

# Questions?
I commented the script pretty thoroughly, but some things may be confusing to read. However, if you have any questions about how my code works, please do let me know and I'll try to explain where I can. I'd advise Googling your question first however, as that often will answer things faster than I can.

# To-do List
- [ ] Release this repo to the public.

# Notes
* **Big** shout-out to [RedditPreview](http://redditpreview.com/) as it helped immensely with debugging the Markup formatting!
* If you'd like to look into Reddit's API, check out their development information [here](https://www.reddit.com/dev/api/).
