import praw
import time


def comment_check(comment_list):
    if len(comment_list) > 1:
        return True
    for comment in comment_list:
        if comment.score < 0:
            return True
    return False


def find_jmod_comments(post):
    comment_list = []

    while True:
        try:
            post.comments.replace_more(limit=0)
            break
        except Exception:
            print('Handling replace_more exception')
            time.sleep(1)

    for comment in post.comments.list():
        if comment.author_flair_css_class == "jagexmod" or comment.author_flair_css_class == "modmatk" \
                or comment.author_flair_css_class == "mod-jagex":
            comment_list.append(comment)
    return comment_list


def create_comment(target_comments, bot_comments):
    for comment in bot_comments:
        if comment.link_id == target_comments[0].link_id:
            return True
    return None


reddit = praw.Reddit('JMOD_Bloodhound', user_agent='User Agent - JMOD_Bloodhound PS Script')
subreddit = reddit.subreddit('2007scape')

bot_list = []

for comment in reddit.redditor('JMOD_Bloodhound').comments.new(limit=None):
    bot_list.append(comment)

for submission in subreddit.hot(limit=1):
    print(submission.title)
    jmod_list = (find_jmod_comments(submission))
    if comment_check(jmod_list):
        if create_comment(jmod_list, bot_list):
            print("JMOD comments be ere mateys")
