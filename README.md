# JMOD_Bloodhound
[Reddit Bot] **Python**~~Powershell~~ script that actively checks [/r/2007scape/](https://www.reddit.com/r/2007scape/hot) and [/r/runescape/](https://www.reddit.com/r/runescape/hot) for posts with JMOD replies and links them within the specified post.

# How It Works
1. The script is scheduled to check [/r/2007scape/](https://www.reddit.com/r/2007scape/hot) and [/r/runescape/](https://www.reddit.com/r/runescape/hot) every 5 minutes for top 100 hot posts with JMOD replies.
	- **The bot also requires that the post have more than 10 comments AND (a JMOD comment with negative comment OR more than one JMOD comment).**
2. After finding a match, the script caches the post's ID via Reddit's save function to verify if a post has been touched already.
3. If a post hasn't been visted previously, it will create a new comment containing a list of each JMOD's comments on that particular thread.
	- It will also create a thread in [/r/TrackedJMODComments/](https://www.reddit.com/r/TrackedJMODComments/new) with each comment from the JMODs underneath it.
4. If a post has been visited previously AND there are new JMOD comments, the script will update the previous comment it had made with the new information.
5. After a post with a J-MOD reply goes beyond the top 100 hot posts within [/r/2007scape/](https://www.reddit.com/r/2007scape/hot) or [/r/runescape/](https://www.reddit.com/r/runescape/hot), the bot will no longer maintain its list of replies (unless the post reaches in the top 100 again).

# Questions?
I commented the script pretty thoroughly, but some things may be confusing to read. However, if you have any questions about how my code works, please do let me know and I'll try to explain where I can. I'd advise Googling your question first however, as that often will answer things faster than I can.

# To-do List
- [x] Converted to Python, utilizing PRAW. PowerShell script is now no longer maintained.
- [x] Add triggers to bot (more than 10 comments AND (more than 1 J-MOD comment OR a J-MOD comment with a hardset negative karma)).
- [x] Add [/r/runescape/](https://www.reddit.com/r/runescape/hot) to bot's search range.
- [x] Change main body of script into a function for versatile use with OSRS and RS3.
- [x] Implement context to JMOD comments where applicable.
- [x] Implement detailed comment information in the bot's post.
- [x] Change the many try-catch calls into a function.
- [x] Release the hound (to the public).

# Notes
* **Big** shout-out to [RedditPreview](http://redditpreview.com/) as it helped immensely with debugging the Markup formatting!
* If you'd like to look into Reddit's API, check out their development information [here](https://www.reddit.com/dev/api/).
* Check out [PRAW](https://praw.readthedocs.io/en/latest/) for a more fluid/ease-of-use of Reddit's API via Python.