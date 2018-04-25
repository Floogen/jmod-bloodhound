# JMOD_Bloodhound
[Reddit Bot] **Powershell** script that actively checks [/r/2007scape/](https://www.reddit.com/r/2007scape/new) for posts with JMOD replies and links them within the specified post.

# How It Works
1. The script is scheduled to check [/r/2007scape/](https://www.reddit.com/r/2007scape/new) every 5 minutes for top 100 hot posts with JMOD replies.
2. After finding a match, the script caches the post's ID via Reddit's save function to verify if a post has been touched already.
3. If a post hasn't been visted previously, it will create a new comment containing a list of each JMOD's comments on that particular thread.
4. If a post has been visited previously AND there are new JMOD comments, the script will update the previous comment it had made with the new information.
5. After a post with a J-MOD reply goes beyond the top 100 hot posts within [/r/2007scape/](https://www.reddit.com/r/2007scape/new), the bot will no longer maintain it's list of replies (unless the post reaches in the top 100 again).

# Questions?
I commented the script pretty thoroughly, but some things may be confusing to read. However, if you have any questions about how my code works, please do let me know and I'll try to explain where I can. I'd advise Googling your question first however, as that often will answer things faster than I can.

# To-do List
- [x] Implement detailed comment information in the bot's post
- [ ] Change the many try-catch calls into a function.
- [x] Release the hound (to the public).

# Notes
* **Big** shout-out to [RedditPreview](http://redditpreview.com/) as it helped immensely with debugging the Markup formatting!
* If you'd like to look into Reddit's API, check out their development information [here](https://www.reddit.com/dev/api/).
