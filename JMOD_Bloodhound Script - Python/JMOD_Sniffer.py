import praw
import time
from datetime import datetime
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
    post_id = 'null'  # change to: target_comments[0].link_id

    for comment in bot_comments:
        if comment.link_id == post_id:
            # bot has commented here before, edit the comment
            return edit_comment(target_comments, comment)

    # create comment instead, as no previous comment was found

    posted_comment = reddit.submission(id='9iiayk').reply(format_comment(target_comments))  # change to: id=post_id
    formatted_comment_body = format_post(target_comments, post_id, posted_comment)

    # create archive of comment on subreddit TrackedJMODComments
    # have post ID in the archive subreddit contain the post name of original target
    # title for each post: [2007scape or Runescape] JMOD Comment(s) On Thread [ThreadName40CharMax...]
    # edited comments will be commented on the archived post
    title = posted_comment.submission.title

    if len(posted_comment.submission.title) > 40:
        title = posted_comment.submission.title[:40] + '...'
    title = '[' + posted_comment.subreddit.display_name + '] (ID:' + posted_comment.link_id + ') ' \
            + 'JMOD Comments On Thread: ' + title

    archive_post_comment(title, formatted_comment_body, target_comments)
    return True


def archive_post_comment(title, post_body, target_comments):
    archived_post = reddit.subreddit('TrackedJMODComments').submit(title=title, selftext=post_body)

    for comment in target_comments:
        if not comment.edited:
            ts = str(datetime.fromtimestamp(comment.created_utc))
            archived_comment = "ID:[" + comment.id + "]\n\nComment by: **" + comment.author.name \
                               + "**\n\nCreated on: **" + ts + "**\n\n---\n\n" + comment.body
        else:
            ts = str(datetime.fromtimestamp(comment.edited))
            archived_comment = "ID:[" + comment.id + "]\n\nComment by: **" + comment.author.name \
                               + "**\n\nEdited on: **" + ts + "**\n\n---\n\n" + comment.body

    reddit.submission(id=archived_post.id).reply(archived_comment)
    return None


def edit_comment(target_comments, past_comment, title):
    print('editing comment')

    # edit archived, alert of any edits
    # get all the archived posts once from new filter?
    return None


def format_post(target_comments, post_id, posted_comment):
    previous_author_name = target_comments[0].author.name

    bot_post_body = '^(ID:[' + posted_comment.submission.id \
                    + '])\n# I have found the following **J-Mod** comments on the thread [' \
                    + posted_comment.submission.title + '](' + posted_comment.submission.permalink + ')\n\n**'\
                    + previous_author_name + '**\n\n'

    for comment in target_comments:
        parsed_comment = comment.body
        if '`n' in parsed_comment or len(parsed_comment) > 45:
            parsed_comment = parsed_comment[:45] + '...'

        if previous_author_name == comment.author.name:
            bot_post_body += '- ^^(ID:[' + comment.id + ']) [' + parsed_comment + '](https://www.reddit.com' \
                                + comment.permalink + '?context=3)\n\n'
        else:
            bot_post_body += '\n\n**' + str(comment.author) + '**\n\n- ^^(ID:[' + comment.id + ']) [' \
                                + parsed_comment + '](https://www.reddit.com' + comment.permalink + '?context=3)\n\n'
            previous_author_name = comment.author.name

    return bot_post_body


def format_comment(target_comments):
    target_comments.sort(key=operator.attrgetter('author.name'))  # sort target_comments by username

    previous_author_name = target_comments[0].author.name
    bot_comment_body = '##### Bark bark!\n\nI have found the following **J-Mod** comment(s) in this thread:\n\n**' \
                       + previous_author_name + '**\n\n'

    for comment in target_comments:
        parsed_comment = comment.body
        if '\n' in parsed_comment or len(parsed_comment) > 45:
            parsed_comment = parsed_comment[:45] + '...'

        if previous_author_name == comment.author.name:
            bot_comment_body += '- [' + parsed_comment + '](https://www.reddit.com' \
                                + comment.permalink + '?context=3)\n\n'
        else:
            bot_comment_body += '\n\n**' + str(comment.author) + '**\n\n- [' \
                                + parsed_comment + '](https://www.reddit.com' + comment.permalink + '?context=3)\n\n'
            previous_author_name = comment.author.name

    current_time = '{:%m/%d/%Y %H:%M:%S}'.format(datetime.now())
    bot_comment_body += "\n\n&nbsp;\n\n^(**Last edited by bot: " + current_time \
                        + "**)\n\n---\n\n^(Hi, I tried my best to find all"\
                        + "the J-Mod's comments in this post.)  \n^(Interested to see how I work? See my post)" \
                        + "^[here](https://www.reddit.com/user/JMOD_Bloodhound/comments/8dronr/jmod_bloodhound" \
                        + "bot_github_repository/?ref=share&ref_source=link) ^(for my GitHub repo!)"

    return bot_comment_body


reddit = praw.Reddit('JMOD_Bloodhound', user_agent='User Agent - JMOD_Bloodhound PS Script')
subreddit = reddit.subreddit('2007scape')

bot_list = []

for comment in reddit.redditor('JMOD_Bloodhound').comments.new(limit=None):
    bot_list.append(comment)

submission = reddit.submission(id='9is7c5')
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