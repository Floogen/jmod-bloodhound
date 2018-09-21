import praw
import time


def comment_check(comment_list):
    if len(comment_list) > 0:
        return True


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


reddit = praw.Reddit('JMOD_Bloodhound', user_agent='User Agent - JMOD_Bloodhound PS Script')

subreddit = reddit.subreddit('2007scape')

for submission in subreddit.hot(limit=1):
    print(submission.title)
    jmod_list = (find_jmod_comments(submission))
    if comment_check(jmod_list):
        print("JMOD comments be ere mateys")
