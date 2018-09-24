import praw
import time
import operator


def comment_check(comment_list):
    if len(comment_list) > 0:  # change back to 1 after testing
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
    post_id = target_comments[0].link_id

    for comment in bot_comments:
        if comment.link_id == post_id:
            # bot has commented here before, edit the comment
            return edit_comment(target_comments, comment)

    # create comment instead, as no previous comment was found
    reddit.submission(id='9iiayk').reply(format_comment(target_comments))  # change to id=post_id
    # create archive of comment on subreddit TrackedJMODComments
    # have post ID in the archive subreddit contain the post name of original target
    return True


def edit_comment(target_comments, past_comment):
    print('ere')
    return None


def format_comment(target_comments):
    target_comments.sort(key=operator.attrgetter('author.name'))  # sort target_comments by username

    previous_author_name = target_comments[0].author.name
    bot_comment_body = '##### Bark bark!\n\nI have found the following **J-Mod** comments in this thread:\n\n**' \
                       + previous_author_name + '**\n\n'

    for comment in target_comments:
        parsed_comment = comment.body
        if '`n' in parsed_comment or len(parsed_comment) > 45:
            parsed_comment = parsed_comment[:45] + '...'

        if previous_author_name == comment.author.name:
            bot_comment_body += '- [' + parsed_comment + '](https://www.reddit.com' \
                                + comment.permalink + '?context=3)\n\n'
        else:
            bot_comment_body += '\n\n**' + str(comment.author) + '**\n\n- [' \
                                + parsed_comment + '](https://www.reddit.com' + comment.permalink + '?context=3)\n\n'
            previous_author_name = comment.author.name

    return bot_comment_body


reddit = praw.Reddit('JMOD_Bloodhound', user_agent='User Agent - JMOD_Bloodhound PS Script')
subreddit = reddit.subreddit('2007scape')

bot_list = []

for comment in reddit.redditor('JMOD_Bloodhound').comments.new(limit=None):
    bot_list.append(comment)

submission = reddit.submission(id='9ih5co')
jmod_list = (find_jmod_comments(submission))
if comment_check(jmod_list):
    if create_comment(jmod_list, bot_list):
        print(submission.title)
        print("JMOD comments be ere mateys")

'''
reddit = praw.Reddit('JMOD_Bloodhound', user_agent='User Agent - JMOD_Bloodhound PS Script')
subreddit = reddit.subreddit('2007scape')

bot_list = []

for comment in reddit.redditor('JMOD_Bloodhound').comments.new(limit=None):
    bot_list.append(comment)

for submission in subreddit.hot(limit=15):
    jmod_list = (find_jmod_comments(submission))
    if comment_check(jmod_list):
        if create_comment(jmod_list, bot_list):
            print(submission.title)
            print("JMOD comments be ere mateys")
'''