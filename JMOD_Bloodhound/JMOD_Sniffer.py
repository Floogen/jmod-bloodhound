import praw
import time
import operator
import re
import configparser
from datetime import datetime
from praw.models import MoreComments


def comment_check(comment_list, subreddit_name, comment_count):
    if subreddit_name == '2007scape' and len(comment_list) > 0:
        return True

    if len(comment_list) > 1 and comment_count > 25:
        return True

    for comment in comment_list:
        if comment.score < 0:
            return True
    return False


def find_jmod_comments(post):
    comment_list = []

    jmod_flairs = config["DEFAULT"]["flairs"].replace(" ", "").split(",")

    while True:
        try:
            post.comments.replace_more(limit=None)
            break
        except Exception:
            print('Handling replace_more exception')
            time.sleep(1)

    for comment in post.comments.list():
        if comment.author_flair_css_class in jmod_flairs:
            comment_list.append(comment)
    return comment_list


def find_bot_comment(post):
    for comment in post.comments:
        if isinstance(comment, MoreComments) or comment.author is None:
            continue
        if comment.author.name == 'JMOD_Bloodhound' and comment.parent_id == f"t3_{post.id}":
            return comment
    return None


def create_comment(target_comments, bot_comments, archived_posts):
    post_id = target_comments[0].submission.id

    for comment in bot_comments:
        if comment.submission.id == post_id and comment.parent_id == f"t3_{post_id}":
            # bot has commented here before, edit the comment
            return edit_comment(target_comments, comment, archived_posts)

    bot_comment = find_bot_comment(target_comments[0].submission)
    if bot_comment is not None:
        return edit_comment(target_comments, bot_comment, archived_posts)

    # create comment instead, as no previous comment was found
    posted_comment = bloodhound_bot.submission(id=post_id).reply(format_comment(target_comments, True))
    formatted_comment_body = format_post(target_comments, posted_comment)

    # create archive of comment on subreddit TrackedJMODComments
    # have post ID in the archive subreddit contain the post name of original target
    # title for each post: [2007scape or Runescape] JMOD Comment(s) On Thread [ThreadName40CharMax...]
    # edited comments will be commented on the archived post
    title = posted_comment.submission.title

    if len(posted_comment.submission.title) > 40:
        title = posted_comment.submission.title[:40].rstrip() + '...'
    title = '[' + posted_comment.subreddit.display_name + '] (ID:' + posted_comment.submission.id + ') ' \
            + 'JMOD Comments On Thread: ' + title

    archive_comments(target_comments
                     , historian_bot.subreddit('TrackedJMODComments').submit(title=title
                                                                             , selftext=formatted_comment_body))
    return True


def edit_comment(target_comments, past_comment, archived_posts):
    # edit archived, alert of any edits
    # get the archived post id of this submission
    arch_post = None

    for post in archived_posts:
        if re.search(r"ID:(.*?)\)", post.title).group(1) == past_comment.submission.id:
            arch_post = post
            # call format_comment and add additional parameter for initialPass?
            # that way it can have logic for flagging comments that have been edited since last pass through

            # initialPass was False, but set to True to disable tracking and editing of JMOD comments
            past_comment.edit(format_comment(target_comments, True, arch_post))
            arch_post.edit(format_post(target_comments, past_comment))
            archive_comments(target_comments, arch_post)
            return

    if not arch_post:
        formatted_comment_body = format_post(target_comments, past_comment)
        title = past_comment.submission.title

        if len(past_comment.submission.title) > 40:
            title = past_comment.submission.title[:40].rstrip() + '...'

        title = '[' + past_comment.subreddit.display_name + '] (ID:' + past_comment.submission.id + ') ' \
                + 'JMOD Comments On Thread: ' + title

        arch_post = historian_bot.subreddit('TrackedJMODComments').submit(title=title, selftext=formatted_comment_body)
        archive_comments(target_comments, arch_post)

    return None


def archive_comments(target_comments, archived_post):
    for comment in target_comments:
        found = False
        new_edit = False
        target_arch_comment = None

        archived_post.comment_sort = 'new'
        for arch_comment in reversed(archived_post.comments):
            comment_first_line = arch_comment.body.splitlines()[0]
            if re.search(r"ID:\[(.*?)\]", comment_first_line).group(1) == comment.id:
                found = True
                archived_ts = datetime.strptime(arch_comment.body.splitlines()[2].split('on: ')[1].replace('**', '')
                                                , '%Y-%m-%d %H:%M:%S').timestamp()
                if comment.edited and archived_ts < comment.edited:
                    new_edit = True
                    target_arch_comment = arch_comment
                elif comment.edited and archived_ts >= comment.edited:
                    new_edit = False

        if new_edit:
            ts = str(datetime.fromtimestamp(comment.edited))
            archived_comment = "ID:[" + comment.id + "]\n\nEdited on: **" + ts \
                               + "**\n\nComment by: **" + comment.author.name \
                               + "**\n\n**[Click here for comment context](" \
                               + comment.permalink + "?context=3)**\n\n---\n\n" \
                               + comment.body \
                               + '\n\n---'
            target_arch_comment.edit(archived_comment)
        elif not found:
            ts = str(datetime.fromtimestamp(comment.created_utc))
            archived_comment = "ID:[" + comment.id + "]\n\nCreated on: **" + ts \
                               + "**\n\nComment by: **" + comment.author.name \
                               + "**\n\n**[Click here for comment context](" \
                               + comment.permalink + "?context=3)**\n\n---\n\n" \
                               + comment.body \
                               + '\n\n---'
            historian_bot.submission(id=archived_post.id).reply(archived_comment)

    return None


def format_post(target_comments, posted_comment):
    previous_author_name = target_comments[0].author.name

    bot_post_body = '# I have found the following **J-Mod** comments on the thread [' \
                    + posted_comment.submission.title + '](' + posted_comment.submission.permalink + ')\n\n**'\
                    + previous_author_name + '**\n\n'

    for comment in target_comments:
        parsed_comment = comment.body
        if '\n' in parsed_comment or len(parsed_comment) > 45:
            parsed_comment = parsed_comment[:45].rstrip() + '...'
            if '\n' in parsed_comment:
                parsed_comment = parsed_comment.splitlines()[0].rstrip() + '...'

        if previous_author_name == comment.author.name:
            bot_post_body += '- ^^(ID:[' + comment.id + ']) [' + parsed_comment + '](' \
                                + comment.permalink + '?context=3)\n\n'
        else:
            bot_post_body += '\n\n**' + str(comment.author) + '**\n\n- ^^(ID:[' + comment.id + ']) [' \
                                + parsed_comment + '](' + comment.permalink + '?context=3)\n\n'
            previous_author_name = comment.author.name

    return bot_post_body


def format_comment(target_comments, initial_pass, archived_post=None):
    target_comments.sort(key=operator.attrgetter('author.name'))  # sort target_comments by username

    previous_author_name = target_comments[0].author.name
    bot_comment_body = '##### Bark bark!\n\nI have found the following **J-Mod** comment(s) in this thread:\n\n**' \
                       + previous_author_name + '**\n\n'

    for comment in target_comments:
        comment_edited_marker = ''
        # disabled the tracking and labeling of edited comments
        if comment.edited and archived_post and not initial_pass:
            edit_counter = 0

            # sort by newest, then foreach through list in reverse to get the oldest
            archived_post.comment_sort = 'new'
            for arch_comment in reversed(archived_post.comments):
                # look for id matching comment.id in first line of each comment
                # and check for creation/edited time
                comment_first_line = arch_comment.body.splitlines()[0]
                if re.search(r"ID:\[(.*?)\]", comment_first_line).group(1) == comment.id:
                    archived_ts = datetime.strptime(arch_comment.body.splitlines()[2].split('on: ')[1].replace('**', '')
                                                    , '%Y-%m-%d %H:%M:%S').timestamp()
                    if archived_ts < comment.edited:
                        if edit_counter == 0:
                            comment_edited_marker = ' [^[original ^comment]](' \
                                                    + arch_comment.permalink + ')'
                        else:
                            comment_edited_marker += '^(, )[^[edit ^' + str(edit_counter) \
                                                     + ']](' + arch_comment.permalink + ')'
                        edit_counter += 1

        parsed_comment = comment.body
        if '\n' in parsed_comment or len(parsed_comment) > 45:
            parsed_comment = parsed_comment[:45].rstrip() + '...'
            if '\n' in parsed_comment:
                parsed_comment = parsed_comment.splitlines()[0].rstrip() + '...'

        if previous_author_name == comment.author.name:
            bot_comment_body += '- [' + parsed_comment + '](' \
                                + comment.permalink + '?context=3)' + comment_edited_marker + '\n\n'
        else:
            bot_comment_body += '\n\n**' + str(comment.author) + '**\n\n- [' \
                                + parsed_comment + '](' + comment.permalink + '?context=3)' \
                                + comment_edited_marker + '\n\n'
            previous_author_name = comment.author.name

    current_time = '{:%m/%d/%Y %H:%M:%S}'.format(datetime.now())
    bot_comment_body += "\n\n&nbsp;\n\n^(**Last edited by bot: " + current_time \
                        + "**)\n\n---\n\n^(I've been rewritten to use Python! I also now archive JMOD comments.)" \
                        + "  \n^(Read more about) [^(the update here)](/u/JMOD_Bloodhound/" \
                          "comments/9kqvis/bot_update_python_archiving/) ^(or see my) [^(Github repo here)]" \
                          "(/u/JMOD_Bloodhound/comments/8dronr/" \
                          "jmod_bloodhoundbot_github_repository/)^."

    return bot_comment_body


def hunt(subreddit_name):
    subreddit = bloodhound_bot.subreddit(subreddit_name)

    bot_list = []

    for comment in bloodhound_bot.redditor('JMOD_Bloodhound').comments.new(limit=None):
        bot_list.append(comment)

    tracked_posts_list = []

    for submission in historian_bot.subreddit('TrackedJMODComments').new(limit=100):
        try:
            submission_id = re.search(r"ID:(.*?)\)", submission.title).group(1)
        except AttributeError:
            submission_id = ''

        if submission_id != '':
            tracked_posts_list.append(submission)

    for submission in subreddit.hot(limit=100):
        if submission.author != 'JMOD_Bloodhound':
            jmod_list = (find_jmod_comments(submission))
            if comment_check(jmod_list, subreddit_name, submission.num_comments):
                if create_comment(jmod_list, bot_list, tracked_posts_list):
                    print(submission.title)
    return None

config = configparser.ConfigParser();
config.read("config.cfg")

subreddits = config["DEFAULT"]["subreddits"].replace(" ", "").split(",")

bloodhound_bot = praw.Reddit('JMOD_Bloodhound', user_agent='User Agent - JMOD_Bloodhound Python Script')
historian_bot = praw.Reddit('JMOD_Historian', user_agent='User Agent - JMOD_Historian Python Script')

for subreddit in subreddits:
    hunt(subreddit)
