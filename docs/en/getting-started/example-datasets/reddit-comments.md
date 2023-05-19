---
slug: /en/getting-started/example-datasets/reddit-comments
sidebar_label: Reddit comments
---

# Reddit comments dataset

This dataset contains publicly-available comments on Reddit that go back to December, 2005, to March, 2023, and contains over 7B rows of data. The raw data is in JSON format in compressed `.zst` files and the rows look like the following:

```json
{"controversiality":0,"body":"A look at Vietnam and Mexico exposes the myth of market liberalisation.","subreddit_id":"t5_6","link_id":"t3_17863","stickied":false,"subreddit":"reddit.com","score":2,"ups":2,"author_flair_css_class":null,"created_utc":1134365188,"author_flair_text":null,"author":"frjo","id":"c13","edited":false,"parent_id":"t3_17863","gilded":0,"distinguished":null,"retrieved_on":1473738411}
{"created_utc":1134365725,"author_flair_css_class":null,"score":1,"ups":1,"subreddit":"reddit.com","stickied":false,"link_id":"t3_17866","subreddit_id":"t5_6","controversiality":0,"body":"The site states \"What can I use it for? Meeting notes, Reports, technical specs Sign-up sheets, proposals and much more...\", just like any other new breeed of sites that want us to store everything we have on the web. And they even guarantee multiple levels of security and encryption etc. But what prevents these web site operators fom accessing and/or stealing Meeting notes, Reports, technical specs Sign-up sheets, proposals and much more, for competitive or personal gains...? I am pretty sure that most of them are honest, but what's there to prevent me from setting up a good useful site and stealing all your data? Call me paranoid - I am.","retrieved_on":1473738411,"distinguished":null,"gilded":0,"id":"c14","edited":false,"parent_id":"t3_17866","author":"zse7zse","author_flair_text":null}
{"gilded":0,"distinguished":null,"retrieved_on":1473738411,"author":"[deleted]","author_flair_text":null,"edited":false,"id":"c15","parent_id":"t3_17869","subreddit":"reddit.com","score":0,"ups":0,"created_utc":1134366848,"author_flair_css_class":null,"body":"Jython related topics by Frank Wierzbicki","controversiality":0,"subreddit_id":"t5_6","stickied":false,"link_id":"t3_17869"}
{"gilded":0,"retrieved_on":1473738411,"distinguished":null,"author_flair_text":null,"author":"[deleted]","edited":false,"parent_id":"t3_17870","id":"c16","subreddit":"reddit.com","created_utc":1134367660,"author_flair_css_class":null,"score":1,"ups":1,"body":"[deleted]","controversiality":0,"stickied":false,"link_id":"t3_17870","subreddit_id":"t5_6"}
{"gilded":0,"retrieved_on":1473738411,"distinguished":null,"author_flair_text":null,"author":"rjoseph","edited":false,"id":"c17","parent_id":"t3_17817","subreddit":"reddit.com","author_flair_css_class":null,"created_utc":1134367754,"score":1,"ups":1,"body":"Saft is by far the best extension you could tak onto your Safari","controversiality":0,"link_id":"t3_17817","stickied":false,"subreddit_id":"t5_6"}
```

A shoutout to Percona for the [motivation behind ingesting this dataset](https://www.percona.com/blog/big-data-set-reddit-comments-analyzing-clickhouse/), which we have downloaded and stored in an S3 bucket.

:::note
The following commands were executed on ClickHouse Cloud. To run this on your own cluster, replace `default` in the `s3Cluster` function call with the name of your cluster. If you do not have a cluster, then replace the `s3Cluster` function with the `s3` function.
:::

1. Let's create a table for the Reddit data:

```sql
CREATE TABLE reddit
(
    subreddit LowCardinality(String),
    subreddit_id LowCardinality(String),
    subreddit_type Enum('public' = 1, 'restricted' = 2, 'user' = 3, 'archived' = 4, 'gold_restricted' = 5, 'private' = 6),
    author LowCardinality(String),
    body String CODEC(ZSTD(6)),
    created_date Date DEFAULT toDate(created_utc),
    created_utc DateTime,
    retrieved_on DateTime,
    id String,
    parent_id String,
    link_id String,
    score Int32,
    total_awards_received UInt16,
    controversiality UInt8,
    gilded UInt8,
    collapsed_because_crowd_control UInt8,
    collapsed_reason Enum('' = 0, 'comment score below threshold' = 1, 'may be sensitive content' = 2, 'potentially toxic' = 3, 'potentially toxic content' = 4),
    distinguished Enum('' = 0, 'moderator' = 1, 'admin' = 2, 'special' = 3),
    removal_reason Enum('' = 0, 'legal' = 1),
    author_created_utc DateTime,
    author_fullname LowCardinality(String),
    author_patreon_flair UInt8,
    author_premium UInt8,
    can_gild UInt8,
    can_mod_post UInt8,
    collapsed UInt8,
    is_submitter UInt8,
    _edited String,
    locked UInt8,
    quarantined UInt8,
    no_follow UInt8,
    send_replies UInt8,
    stickied UInt8,
    author_flair_text LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY (subreddit, created_date, author);
```

:::note
The names of the files in S3 start with `RC_YYYY-MM` where `YYYY-MM` goes from `2005-12` to `2023-02`. The compression changes a couple of times though, so the file extensions are not consistent. For example:

- the file names are initially `RC_2005-12.bz2` to `RC_2017-11.bz2`
- then they look like `RC_2017-12.xz` to `RC_2018-09.xz`
- and finally `RC_2018-10.zst` to `RC_2023-02.zst`
:::

2. We are going to start with one month of data, but if you want to simply insert every row - skip ahead to step 8 below. The following file has 86M records from December, 2017:

```sql
INSERT INTO reddit
    SELECT *
    FROM s3Cluster(
        'default',
        'https://clickhouse-public-datasets.s3.eu-central-1.amazonaws.com/reddit/original/RC_2017-12.xz',
        'JSONEachRow'
    );
```

If you do not have a cluster, use `s3` instead of `s3Cluster`:

```sql
INSERT INTO reddit
    SELECT *
    FROM s3(
        'https://clickhouse-public-datasets.s3.eu-central-1.amazonaws.com/reddit/original/RC_2017-12.xz',
        'JSONEachRow'
    );
```

3. It will take a while depending on your resources, but when it's done verify it worked:

```sql
SELECT formatReadableQuantity(count())
FROM reddit;
```

```response
┌─formatReadableQuantity(count())─┐
│ 85.97 million                   │
└─────────────────────────────────┘
```

4. Let's see how many unique subreddits were in December of 2017:

```sql
SELECT uniqExact(subreddit)
FROM reddit;
```

```response
┌─uniqExact(subreddit)─┐
│                91613 │
└──────────────────────┘

1 row in set. Elapsed: 1.572 sec. Processed 85.97 million rows, 367.43 MB (54.71 million rows/s., 233.80 MB/s.)
```

5. This query returns the top 10 subreddits (in terms of number of comments):

```sql
SELECT
    subreddit,
    count() AS c
FROM reddit
GROUP BY subreddit
ORDER BY c DESC
LIMIT 20;
```

```response
┌─subreddit───────┬───────c─┐
│ AskReddit       │ 5245881 │
│ politics        │ 1753120 │
│ nfl             │ 1220266 │
│ nba             │  960388 │
│ The_Donald      │  931857 │
│ news            │  796617 │
│ worldnews       │  765709 │
│ CFB             │  710360 │
│ gaming          │  602761 │
│ movies          │  601966 │
│ soccer          │  590628 │
│ Bitcoin         │  583783 │
│ pics            │  563408 │
│ StarWars        │  562514 │
│ funny           │  547563 │
│ leagueoflegends │  517213 │
│ teenagers       │  492020 │
│ DestinyTheGame  │  477377 │
│ todayilearned   │  472650 │
│ videos          │  450581 │
└─────────────────┴─────────┘

20 rows in set. Elapsed: 0.368 sec. Processed 85.97 million rows, 367.43 MB (233.34 million rows/s., 997.25 MB/s.)
```

6. Here are the top 10 authors in December of 2017, in terms of number of comments posted:

```sql
SELECT
    author,
    count() AS c
FROM reddit
GROUP BY author
ORDER BY c DESC
LIMIT 10;
```

```response
┌─author──────────┬───────c─┐
│ [deleted]       │ 5913324 │
│ AutoModerator   │  784886 │
│ ImagesOfNetwork │   83241 │
│ BitcoinAllBot   │   54484 │
│ imguralbumbot   │   45822 │
│ RPBot           │   29337 │
│ WikiTextBot     │   25982 │
│ Concise_AMA_Bot │   19974 │
│ MTGCardFetcher  │   19103 │
│ TotesMessenger  │   19057 │
└─────────────────┴─────────┘

10 rows in set. Elapsed: 8.143 sec. Processed 85.97 million rows, 711.05 MB (10.56 million rows/s., 87.32 MB/s.)
```

7.  We already inserted some data, but we will start over:

```sql
TRUNCATE TABLE reddit;
```

8. This is a fun dataset and it looks like we can find some great information, so let's go ahead and insert the entire dataset from 2005 to 2023. When you're ready, run this command to insert all the rows. (It takes a while - up to 17 hours!)

```sql
INSERT INTO reddit
SELECT *
FROM s3Cluster(
    'default',
    'https://clickhouse-public-datasets.s3.amazonaws.com/reddit/original/RC*',
    'JSONEachRow'
    )
SETTINGS zstd_window_log_max = 31;
```

The response looks like:

```response
0 rows in set. Elapsed: 61187.839 sec. Processed 6.74 billion rows, 2.06 TB (110.17 thousand rows/s., 33.68 MB/s.)
```

8. Let's see how many rows were inserted and how much disk space the table is using:


```sql
SELECT
    sum(rows) AS count,
    formatReadableQuantity(count),
    formatReadableSize(sum(bytes)) AS disk_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size
FROM system.parts
WHERE (table = 'reddit') AND active
```

Notice the compression of disk storage is about 1/3 of the uncompressed size:

```response
┌──────count─┬─formatReadableQuantity(sum(rows))─┬─disk_size──┬─uncompressed_size─┐
│ 6739503568 │ 6.74 billion                      │ 501.10 GiB │ 1.51 TiB          │
└────────────┴───────────────────────────────────┴────────────┴───────────────────┘

1 row in set. Elapsed: 0.010 sec.
```

9. The following query shows how many comments, authors and subreddits we have for each month:

```sql
SELECT
    toStartOfMonth(created_utc) AS firstOfMonth,
    count() AS c,
    bar(c, 0, 50000000, 25) AS bar_count,
    uniq(author) AS authors,
    bar(authors, 0, 5000000, 25) AS bar_authors,
    uniq(subreddit) AS subreddits,
    bar(subreddits, 0, 100000, 25) AS bar_subreddits
FROM reddit
GROUP BY firstOfMonth
ORDER BY firstOfMonth ASC;
```

This is a substantial query that has to process all 6.74 billion rows, but we still get an impressive response time (about 3 minutes):

```response
┌─firstOfMonth─┬─────────c─┬─bar_count─────────────────┬─authors─┬─bar_authors───────────────┬─subreddits─┬─bar_subreddits────────────┐
│   2005-12-01 │      1075 │                           │     394 │                           │          1 │                           │
│   2006-01-01 │      3666 │                           │     791 │                           │          2 │                           │
│   2006-02-01 │      9095 │                           │    1464 │                           │         18 │                           │
│   2006-03-01 │     13859 │                           │    1958 │                           │         15 │                           │
│   2006-04-01 │     19090 │                           │    2334 │                           │         21 │                           │
│   2006-05-01 │     26859 │                           │    2698 │                           │         21 │                           │
│   2006-06-01 │     29163 │                           │    3043 │                           │         19 │                           │
│   2006-07-01 │     37031 │                           │    3532 │                           │         22 │                           │
│   2006-08-01 │     50559 │                           │    4750 │                           │         24 │                           │
│   2006-09-01 │     50675 │                           │    4908 │                           │         21 │                           │
│   2006-10-01 │     54148 │                           │    5654 │                           │         31 │                           │
│   2006-11-01 │     62021 │                           │    6490 │                           │         23 │                           │
│   2006-12-01 │     61018 │                           │    6707 │                           │         24 │                           │
│   2007-01-01 │     81341 │                           │    7931 │                           │         23 │                           │
│   2007-02-01 │     95634 │                           │    9020 │                           │         21 │                           │
│   2007-03-01 │    112444 │                           │   10842 │                           │         23 │                           │
│   2007-04-01 │    126773 │                           │   10701 │                           │         26 │                           │
│   2007-05-01 │    170097 │                           │   11365 │                           │         25 │                           │
│   2007-06-01 │    178800 │                           │   11267 │                           │         22 │                           │
│   2007-07-01 │    203319 │                           │   12482 │                           │         25 │                           │
│   2007-08-01 │    225111 │                           │   14124 │                           │         30 │                           │
│   2007-09-01 │    259497 │ ▏                         │   15416 │                           │         33 │                           │
│   2007-10-01 │    274170 │ ▏                         │   15302 │                           │         36 │                           │
│   2007-11-01 │    372983 │ ▏                         │   15134 │                           │         43 │                           │
│   2007-12-01 │    363390 │ ▏                         │   15915 │                           │         31 │                           │
│   2008-01-01 │    452990 │ ▏                         │   18857 │                           │        126 │                           │
│   2008-02-01 │    441768 │ ▏                         │   18266 │                           │        173 │                           │
│   2008-03-01 │    463728 │ ▏                         │   18947 │                           │        292 │                           │
│   2008-04-01 │    468317 │ ▏                         │   18590 │                           │        323 │                           │
│   2008-05-01 │    536380 │ ▎                         │   20861 │                           │        375 │                           │
│   2008-06-01 │    577684 │ ▎                         │   22557 │                           │        575 │ ▏                         │
│   2008-07-01 │    592610 │ ▎                         │   23123 │                           │        657 │ ▏                         │
│   2008-08-01 │    595959 │ ▎                         │   23729 │                           │        707 │ ▏                         │
│   2008-09-01 │    680892 │ ▎                         │   26374 │ ▏                         │        801 │ ▏                         │
│   2008-10-01 │    789874 │ ▍                         │   28970 │ ▏                         │        893 │ ▏                         │
│   2008-11-01 │    792310 │ ▍                         │   30272 │ ▏                         │       1024 │ ▎                         │
│   2008-12-01 │    850359 │ ▍                         │   34073 │ ▏                         │       1103 │ ▎                         │
│   2009-01-01 │   1051649 │ ▌                         │   38978 │ ▏                         │       1316 │ ▎                         │
│   2009-02-01 │    944711 │ ▍                         │   43390 │ ▏                         │       1132 │ ▎                         │
│   2009-03-01 │   1048643 │ ▌                         │   46516 │ ▏                         │       1203 │ ▎                         │
│   2009-04-01 │   1094599 │ ▌                         │   48284 │ ▏                         │       1334 │ ▎                         │
│   2009-05-01 │   1201257 │ ▌                         │   52512 │ ▎                         │       1395 │ ▎                         │
│   2009-06-01 │   1258750 │ ▋                         │   57728 │ ▎                         │       1473 │ ▎                         │
│   2009-07-01 │   1470290 │ ▋                         │   60098 │ ▎                         │       1686 │ ▍                         │
│   2009-08-01 │   1750688 │ ▉                         │   67347 │ ▎                         │       1777 │ ▍                         │
│   2009-09-01 │   2032276 │ █                         │   78051 │ ▍                         │       1784 │ ▍                         │
│   2009-10-01 │   2242017 │ █                         │   93409 │ ▍                         │       2071 │ ▌                         │
│   2009-11-01 │   2207444 │ █                         │   95940 │ ▍                         │       2141 │ ▌                         │
│   2009-12-01 │   2560510 │ █▎                        │  104239 │ ▌                         │       2141 │ ▌                         │
│   2010-01-01 │   2884096 │ █▍                        │  114314 │ ▌                         │       2313 │ ▌                         │
│   2010-02-01 │   2687779 │ █▎                        │  115683 │ ▌                         │       2522 │ ▋                         │
│   2010-03-01 │   3228254 │ █▌                        │  125775 │ ▋                         │       2890 │ ▋                         │
│   2010-04-01 │   3209898 │ █▌                        │  128936 │ ▋                         │       3170 │ ▊                         │
│   2010-05-01 │   3267363 │ █▋                        │  131851 │ ▋                         │       3166 │ ▊                         │
│   2010-06-01 │   3532867 │ █▊                        │  139522 │ ▋                         │       3301 │ ▊                         │
│   2010-07-01 │   4032737 │ ██                        │  153451 │ ▊                         │       3662 │ ▉                         │
│   2010-08-01 │   4247982 │ ██                        │  164071 │ ▊                         │       3653 │ ▉                         │
│   2010-09-01 │   4704069 │ ██▎                       │  186613 │ ▉                         │       4009 │ █                         │
│   2010-10-01 │   5032368 │ ██▌                       │  203800 │ █                         │       4154 │ █                         │
│   2010-11-01 │   5689002 │ ██▊                       │  226134 │ █▏                        │       4383 │ █                         │
│   2010-12-01 │   5972642 │ ██▉                       │  245824 │ █▏                        │       4692 │ █▏                        │
│   2011-01-01 │   6603329 │ ███▎                      │  270025 │ █▎                        │       5141 │ █▎                        │
│   2011-02-01 │   6363114 │ ███▏                      │  277593 │ █▍                        │       5202 │ █▎                        │
│   2011-03-01 │   7556165 │ ███▊                      │  314748 │ █▌                        │       5445 │ █▎                        │
│   2011-04-01 │   7571398 │ ███▊                      │  329920 │ █▋                        │       6128 │ █▌                        │
│   2011-05-01 │   8803949 │ ████▍                     │  365013 │ █▊                        │       6834 │ █▋                        │
│   2011-06-01 │   9766511 │ ████▉                     │  393945 │ █▉                        │       7519 │ █▉                        │
│   2011-07-01 │  10557466 │ █████▎                    │  424235 │ ██                        │       8293 │ ██                        │
│   2011-08-01 │  12316144 │ ██████▏                   │  475326 │ ██▍                       │       9657 │ ██▍                       │
│   2011-09-01 │  12150412 │ ██████                    │  503142 │ ██▌                       │      10278 │ ██▌                       │
│   2011-10-01 │  13470278 │ ██████▋                   │  548801 │ ██▋                       │      10922 │ ██▋                       │
│   2011-11-01 │  13621533 │ ██████▊                   │  574435 │ ██▊                       │      11572 │ ██▉                       │
│   2011-12-01 │  14509469 │ ███████▎                  │  622849 │ ███                       │      12335 │ ███                       │
│   2012-01-01 │  16350205 │ ████████▏                 │  696110 │ ███▍                      │      14281 │ ███▌                      │
│   2012-02-01 │  16015695 │ ████████                  │  722892 │ ███▌                      │      14949 │ ███▋                      │
│   2012-03-01 │  17881943 │ ████████▉                 │  789664 │ ███▉                      │      15795 │ ███▉                      │
│   2012-04-01 │  19044534 │ █████████▌                │  842491 │ ████▏                     │      16440 │ ████                      │
│   2012-05-01 │  20388260 │ ██████████▏               │  886176 │ ████▍                     │      16974 │ ████▏                     │
│   2012-06-01 │  21897913 │ ██████████▉               │  946798 │ ████▋                     │      17952 │ ████▍                     │
│   2012-07-01 │  24087517 │ ████████████              │ 1018636 │ █████                     │      19069 │ ████▊                     │
│   2012-08-01 │  25703326 │ ████████████▊             │ 1094445 │ █████▍                    │      20553 │ █████▏                    │
│   2012-09-01 │  23419524 │ ███████████▋              │ 1088491 │ █████▍                    │      20831 │ █████▏                    │
│   2012-10-01 │  24788236 │ ████████████▍             │ 1131885 │ █████▋                    │      21868 │ █████▍                    │
│   2012-11-01 │  24648302 │ ████████████▎             │ 1167608 │ █████▊                    │      21791 │ █████▍                    │
│   2012-12-01 │  26080276 │ █████████████             │ 1218402 │ ██████                    │      22622 │ █████▋                    │
│   2013-01-01 │  30365867 │ ███████████████▏          │ 1341703 │ ██████▋                   │      24696 │ ██████▏                   │
│   2013-02-01 │  27213960 │ █████████████▌            │ 1304756 │ ██████▌                   │      24514 │ ██████▏                   │
│   2013-03-01 │  30771274 │ ███████████████▍          │ 1391703 │ ██████▉                   │      25730 │ ██████▍                   │
│   2013-04-01 │  33259557 │ ████████████████▋         │ 1485971 │ ███████▍                  │      27294 │ ██████▊                   │
│   2013-05-01 │  33126225 │ ████████████████▌         │ 1506473 │ ███████▌                  │      27299 │ ██████▊                   │
│   2013-06-01 │  32648247 │ ████████████████▎         │ 1506650 │ ███████▌                  │      27450 │ ██████▊                   │
│   2013-07-01 │  34922133 │ █████████████████▍        │ 1561771 │ ███████▊                  │      28294 │ ███████                   │
│   2013-08-01 │  34766579 │ █████████████████▍        │ 1589781 │ ███████▉                  │      28943 │ ███████▏                  │
│   2013-09-01 │  31990369 │ ███████████████▉          │ 1570342 │ ███████▊                  │      29408 │ ███████▎                  │
│   2013-10-01 │  35940040 │ █████████████████▉        │ 1683770 │ ████████▍                 │      30273 │ ███████▌                  │
│   2013-11-01 │  37396497 │ ██████████████████▋       │ 1757467 │ ████████▊                 │      31173 │ ███████▊                  │
│   2013-12-01 │  39810216 │ ███████████████████▉      │ 1846204 │ █████████▏                │      32326 │ ████████                  │
│   2014-01-01 │  42420655 │ █████████████████████▏    │ 1927229 │ █████████▋                │      35603 │ ████████▉                 │
│   2014-02-01 │  38703362 │ ███████████████████▎      │ 1874067 │ █████████▎                │      37007 │ █████████▎                │
│   2014-03-01 │  42459956 │ █████████████████████▏    │ 1959888 │ █████████▊                │      37948 │ █████████▍                │
│   2014-04-01 │  42440735 │ █████████████████████▏    │ 1951369 │ █████████▊                │      38362 │ █████████▌                │
│   2014-05-01 │  42514094 │ █████████████████████▎    │ 1970197 │ █████████▊                │      39078 │ █████████▊                │
│   2014-06-01 │  41990650 │ ████████████████████▉     │ 1943850 │ █████████▋                │      38268 │ █████████▌                │
│   2014-07-01 │  46868899 │ ███████████████████████▍  │ 2059346 │ ██████████▎               │      40634 │ ██████████▏               │
│   2014-08-01 │  46990813 │ ███████████████████████▍  │ 2117335 │ ██████████▌               │      41764 │ ██████████▍               │
│   2014-09-01 │  44992201 │ ██████████████████████▍   │ 2124708 │ ██████████▌               │      41890 │ ██████████▍               │
│   2014-10-01 │  47497520 │ ███████████████████████▋  │ 2206535 │ ███████████               │      43109 │ ██████████▊               │
│   2014-11-01 │  46118074 │ ███████████████████████   │ 2239747 │ ███████████▏              │      43718 │ ██████████▉               │
│   2014-12-01 │  48807699 │ ████████████████████████▍ │ 2372945 │ ███████████▊              │      43823 │ ██████████▉               │
│   2015-01-01 │  53851542 │ █████████████████████████ │ 2499536 │ ████████████▍             │      47172 │ ███████████▊              │
│   2015-02-01 │  48342747 │ ████████████████████████▏ │ 2448496 │ ████████████▏             │      47229 │ ███████████▊              │
│   2015-03-01 │  54564441 │ █████████████████████████ │ 2550534 │ ████████████▊             │      48156 │ ████████████              │
│   2015-04-01 │  55005780 │ █████████████████████████ │ 2609443 │ █████████████             │      49865 │ ████████████▍             │
│   2015-05-01 │  54504410 │ █████████████████████████ │ 2585535 │ ████████████▉             │      50137 │ ████████████▌             │
│   2015-06-01 │  54258492 │ █████████████████████████ │ 2595129 │ ████████████▉             │      49598 │ ████████████▍             │
│   2015-07-01 │  58451788 │ █████████████████████████ │ 2720026 │ █████████████▌            │      55022 │ █████████████▊            │
│   2015-08-01 │  58075327 │ █████████████████████████ │ 2743994 │ █████████████▋            │      55302 │ █████████████▊            │
│   2015-09-01 │  55574825 │ █████████████████████████ │ 2672793 │ █████████████▎            │      53960 │ █████████████▍            │
│   2015-10-01 │  59494045 │ █████████████████████████ │ 2816426 │ ██████████████            │      70210 │ █████████████████▌        │
│   2015-11-01 │  57117500 │ █████████████████████████ │ 2847146 │ ██████████████▏           │      71363 │ █████████████████▊        │
│   2015-12-01 │  58523312 │ █████████████████████████ │ 2854840 │ ██████████████▎           │      94559 │ ███████████████████████▋  │
│   2016-01-01 │  61991732 │ █████████████████████████ │ 2920366 │ ██████████████▌           │     108438 │ █████████████████████████ │
│   2016-02-01 │  59189875 │ █████████████████████████ │ 2854683 │ ██████████████▎           │     109916 │ █████████████████████████ │
│   2016-03-01 │  63918864 │ █████████████████████████ │ 2969542 │ ██████████████▊           │      84787 │ █████████████████████▏    │
│   2016-04-01 │  64271256 │ █████████████████████████ │ 2999086 │ ██████████████▉           │      61647 │ ███████████████▍          │
│   2016-05-01 │  65212004 │ █████████████████████████ │ 3034674 │ ███████████████▏          │      67465 │ ████████████████▊         │
│   2016-06-01 │  65867743 │ █████████████████████████ │ 3057604 │ ███████████████▎          │      75170 │ ██████████████████▊       │
│   2016-07-01 │  66974735 │ █████████████████████████ │ 3199374 │ ███████████████▉          │      77732 │ ███████████████████▍      │
│   2016-08-01 │  69654819 │ █████████████████████████ │ 3239957 │ ████████████████▏         │      63080 │ ███████████████▊          │
│   2016-09-01 │  67024973 │ █████████████████████████ │ 3190864 │ ███████████████▉          │      62324 │ ███████████████▌          │
│   2016-10-01 │  71826553 │ █████████████████████████ │ 3284340 │ ████████████████▍         │      62549 │ ███████████████▋          │
│   2016-11-01 │  71022319 │ █████████████████████████ │ 3300822 │ ████████████████▌         │      69718 │ █████████████████▍        │
│   2016-12-01 │  72942967 │ █████████████████████████ │ 3430324 │ █████████████████▏        │      71705 │ █████████████████▉        │
│   2017-01-01 │  78946585 │ █████████████████████████ │ 3572093 │ █████████████████▊        │      78198 │ ███████████████████▌      │
│   2017-02-01 │  70609487 │ █████████████████████████ │ 3421115 │ █████████████████         │      69823 │ █████████████████▍        │
│   2017-03-01 │  79723106 │ █████████████████████████ │ 3638122 │ ██████████████████▏       │      73865 │ ██████████████████▍       │
│   2017-04-01 │  77478009 │ █████████████████████████ │ 3620591 │ ██████████████████        │      74387 │ ██████████████████▌       │
│   2017-05-01 │  79810360 │ █████████████████████████ │ 3650820 │ ██████████████████▎       │      74356 │ ██████████████████▌       │
│   2017-06-01 │  79901711 │ █████████████████████████ │ 3737614 │ ██████████████████▋       │      72114 │ ██████████████████        │
│   2017-07-01 │  81798725 │ █████████████████████████ │ 3872330 │ ███████████████████▎      │      76052 │ ███████████████████       │
│   2017-08-01 │  84658503 │ █████████████████████████ │ 3960093 │ ███████████████████▊      │      77798 │ ███████████████████▍      │
│   2017-09-01 │  83165192 │ █████████████████████████ │ 3880501 │ ███████████████████▍      │      78402 │ ███████████████████▌      │
│   2017-10-01 │  85828912 │ █████████████████████████ │ 3980335 │ ███████████████████▉      │      80685 │ ████████████████████▏     │
│   2017-11-01 │  84965681 │ █████████████████████████ │ 4026749 │ ████████████████████▏     │      82659 │ ████████████████████▋     │
│   2017-12-01 │  85973810 │ █████████████████████████ │ 4196354 │ ████████████████████▉     │      91984 │ ██████████████████████▉   │
│   2018-01-01 │  91558594 │ █████████████████████████ │ 4364443 │ █████████████████████▊    │     102577 │ █████████████████████████ │
│   2018-02-01 │  86467179 │ █████████████████████████ │ 4277899 │ █████████████████████▍    │     104610 │ █████████████████████████ │
│   2018-03-01 │  96490262 │ █████████████████████████ │ 4422470 │ ██████████████████████    │     112559 │ █████████████████████████ │
│   2018-04-01 │  98101232 │ █████████████████████████ │ 4572434 │ ██████████████████████▊   │     105284 │ █████████████████████████ │
│   2018-05-01 │ 100109100 │ █████████████████████████ │ 4698908 │ ███████████████████████▍  │     103910 │ █████████████████████████ │
│   2018-06-01 │ 100009462 │ █████████████████████████ │ 4697426 │ ███████████████████████▍  │     101107 │ █████████████████████████ │
│   2018-07-01 │ 108151359 │ █████████████████████████ │ 5099492 │ █████████████████████████ │     106184 │ █████████████████████████ │
│   2018-08-01 │ 107330940 │ █████████████████████████ │ 5084082 │ █████████████████████████ │     109985 │ █████████████████████████ │
│   2018-09-01 │ 104473929 │ █████████████████████████ │ 5011953 │ █████████████████████████ │     109710 │ █████████████████████████ │
│   2018-10-01 │ 112346556 │ █████████████████████████ │ 5320405 │ █████████████████████████ │     112533 │ █████████████████████████ │
│   2018-11-01 │ 112573001 │ █████████████████████████ │ 5353282 │ █████████████████████████ │     112211 │ █████████████████████████ │
│   2018-12-01 │ 121953600 │ █████████████████████████ │ 5611543 │ █████████████████████████ │     118291 │ █████████████████████████ │
│   2019-01-01 │ 129386587 │ █████████████████████████ │ 6016687 │ █████████████████████████ │     125725 │ █████████████████████████ │
│   2019-02-01 │ 120645639 │ █████████████████████████ │ 5974488 │ █████████████████████████ │     125420 │ █████████████████████████ │
│   2019-03-01 │ 137650471 │ █████████████████████████ │ 6410197 │ █████████████████████████ │     135924 │ █████████████████████████ │
│   2019-04-01 │ 138473643 │ █████████████████████████ │ 6416384 │ █████████████████████████ │     139844 │ █████████████████████████ │
│   2019-05-01 │ 142463421 │ █████████████████████████ │ 6574836 │ █████████████████████████ │     142012 │ █████████████████████████ │
│   2019-06-01 │ 134172939 │ █████████████████████████ │ 6601267 │ █████████████████████████ │     140997 │ █████████████████████████ │
│   2019-07-01 │ 145965083 │ █████████████████████████ │ 6901822 │ █████████████████████████ │     147802 │ █████████████████████████ │
│   2019-08-01 │ 146854393 │ █████████████████████████ │ 6993882 │ █████████████████████████ │     151888 │ █████████████████████████ │
│   2019-09-01 │ 137540219 │ █████████████████████████ │ 7001362 │ █████████████████████████ │     148839 │ █████████████████████████ │
│   2019-10-01 │ 129771456 │ █████████████████████████ │ 6825690 │ █████████████████████████ │     144453 │ █████████████████████████ │
│   2019-11-01 │ 107990259 │ █████████████████████████ │ 6368286 │ █████████████████████████ │     141768 │ █████████████████████████ │
│   2019-12-01 │ 112895934 │ █████████████████████████ │ 6640902 │ █████████████████████████ │     148277 │ █████████████████████████ │
│   2020-01-01 │  54354879 │ █████████████████████████ │ 4782339 │ ███████████████████████▉  │     111658 │ █████████████████████████ │
│   2020-02-01 │  22696923 │ ███████████▎              │ 3135175 │ ███████████████▋          │      79521 │ ███████████████████▉      │
│   2020-03-01 │   3466677 │ █▋                        │  987960 │ ████▉                     │      40901 │ ██████████▏               │
└──────────────┴───────────┴───────────────────────────┴─────────┴───────────────────────────┴────────────┴───────────────────────────┘

172 rows in set. Elapsed: 184.809 sec. Processed 6.74 billion rows, 89.56 GB (36.47 million rows/s., 484.62 MB/s.)
```

10. Here are the top 10 subreddits of 2022:

```sql
SELECT
    subreddit,
    count() AS count
FROM reddit
WHERE toYear(created_utc) = 2022
GROUP BY subreddit
ORDER BY count DESC
LIMIT 10;
```

The response is:

```response
┌─subreddit────────┬───count─┐
│ AskReddit        │ 3858203 │
│ politics         │ 1356782 │
│ memes            │ 1249120 │
│ nfl              │  883667 │
│ worldnews        │  866065 │
│ teenagers        │  777095 │
│ AmItheAsshole    │  752720 │
│ dankmemes        │  657932 │
│ nba              │  514184 │
│ unpopularopinion │  473649 │
└──────────────────┴─────────┘

10 rows in set. Elapsed: 27.824 sec. Processed 6.74 billion rows, 53.26 GB (242.22 million rows/s., 1.91 GB/s.)
```

11. Let's see which subreddits had the biggest increase in commnents from 2018 to 2019:

```sql
SELECT
    subreddit,
    newcount - oldcount AS diff
FROM
(
    SELECT
        subreddit,
        count(*) AS newcount
    FROM reddit
    WHERE toYear(created_utc) = 2019
    GROUP BY subreddit
)
ALL INNER JOIN
(
    SELECT
        subreddit,
        count(*) AS oldcount
    FROM reddit
    WHERE toYear(created_utc) = 2018
    GROUP BY subreddit
) USING (subreddit)
ORDER BY diff DESC
LIMIT 50
SETTINGS joined_subquery_requires_alias = 0;
```

It looks like memes and teenagers were busy on Reddit in 2019:

```response
┌─subreddit────────────┬─────diff─┐
│ memes                │ 15368369 │
│ AskReddit            │ 14663662 │
│ teenagers            │ 12266991 │
│ AmItheAsshole        │ 11561538 │
│ dankmemes            │ 11305158 │
│ unpopularopinion     │  6332772 │
│ PewdiepieSubmissions │  5930818 │
│ Market76             │  5014668 │
│ relationship_advice  │  3776383 │
│ freefolk             │  3169236 │
│ Minecraft            │  3160241 │
│ classicwow           │  2907056 │
│ Animemes             │  2673398 │
│ gameofthrones        │  2402835 │
│ PublicFreakout       │  2267605 │
│ ShitPostCrusaders    │  2207266 │
│ RoastMe              │  2195715 │
│ gonewild             │  2148649 │
│ AnthemTheGame        │  1803818 │
│ entitledparents      │  1706270 │
│ MortalKombat         │  1679508 │
│ Cringetopia          │  1620555 │
│ pokemon              │  1615266 │
│ HistoryMemes         │  1608289 │
│ Brawlstars           │  1574977 │
│ iamatotalpieceofshit │  1558315 │
│ trashy               │  1518549 │
│ ChapoTrapHouse       │  1505748 │
│ Pikabu               │  1501001 │
│ Showerthoughts       │  1475101 │
│ cursedcomments       │  1465607 │
│ ukpolitics           │  1386043 │
│ wallstreetbets       │  1384431 │
│ interestingasfuck    │  1378900 │
│ wholesomememes       │  1353333 │
│ AskOuija             │  1233263 │
│ borderlands3         │  1197192 │
│ aww                  │  1168257 │
│ insanepeoplefacebook │  1155473 │
│ FortniteCompetitive  │  1122778 │
│ EpicSeven            │  1117380 │
│ FreeKarma4U          │  1116423 │
│ YangForPresidentHQ   │  1086700 │
│ SquaredCircle        │  1044089 │
│ MurderedByWords      │  1042511 │
│ AskMen               │  1024434 │
│ thedivision          │  1016634 │
│ barstoolsports       │   985032 │
│ nfl                  │   978340 │
│ BattlefieldV         │   971408 │
└──────────────────────┴──────────┘

50 rows in set. Elapsed: 65.954 sec. Processed 13.48 billion rows, 79.67 GB (204.37 million rows/s., 1.21 GB/s.)
```

12. One more query: let's compare ClickHouse mentions to other technologies like Snowflake and Postgres. This query is a big one because it has to search all the comments three times for a substring, and unfortunately ClickHouse user are obviously not very active on Reddit yet:

```sql
SELECT
    toStartOfQuarter(created_utc) AS quarter,
    sum(if(positionCaseInsensitive(body, 'clickhouse') > 0, 1, 0)) AS clickhouse,
    sum(if(positionCaseInsensitive(body, 'snowflake') > 0, 1, 0)) AS snowflake,
    sum(if(positionCaseInsensitive(body, 'postgres') > 0, 1, 0)) AS postgres
FROM reddit
GROUP BY quarter
ORDER BY quarter ASC;
```

```response
┌────Quarter─┬─clickhouse─┬─snowflake─┬─postgres─┐
│ 2005-10-01 │          0 │         0 │        0 │
│ 2006-01-01 │          0 │         2 │       23 │
│ 2006-04-01 │          0 │         2 │       24 │
│ 2006-07-01 │          0 │         4 │       13 │
│ 2006-10-01 │          0 │        23 │       73 │
│ 2007-01-01 │          0 │        14 │       91 │
│ 2007-04-01 │          0 │        10 │       59 │
│ 2007-07-01 │          0 │        39 │      116 │
│ 2007-10-01 │          0 │        45 │      125 │
│ 2008-01-01 │          0 │        53 │      234 │
│ 2008-04-01 │          0 │        79 │      303 │
│ 2008-07-01 │          0 │       102 │      174 │
│ 2008-10-01 │          0 │       156 │      323 │
│ 2009-01-01 │          0 │       206 │      208 │
│ 2009-04-01 │          0 │       178 │      417 │
│ 2009-07-01 │          0 │       300 │      295 │
│ 2009-10-01 │          0 │       633 │      589 │
│ 2010-01-01 │          0 │       555 │      501 │
│ 2010-04-01 │          0 │       587 │      469 │
│ 2010-07-01 │          0 │       770 │      821 │
│ 2010-10-01 │          0 │      1480 │      550 │
│ 2011-01-01 │          0 │      1482 │      568 │
│ 2011-04-01 │          0 │      1558 │      406 │
│ 2011-07-01 │          0 │      2163 │      628 │
│ 2011-10-01 │          0 │      4064 │      566 │
│ 2012-01-01 │          0 │      4621 │      662 │
│ 2012-04-01 │          0 │      5737 │      785 │
│ 2012-07-01 │          0 │      6097 │     1127 │
│ 2012-10-01 │          0 │      7986 │      600 │
│ 2013-01-01 │          0 │      9704 │      839 │
│ 2013-04-01 │          0 │      8161 │      853 │
│ 2013-07-01 │          0 │      9704 │     1028 │
│ 2013-10-01 │          0 │     12879 │     1404 │
│ 2014-01-01 │          0 │     12317 │     1548 │
│ 2014-04-01 │          0 │     13181 │     1577 │
│ 2014-07-01 │          0 │     15640 │     1710 │
│ 2014-10-01 │          0 │     19479 │     1959 │
│ 2015-01-01 │          0 │     20411 │     2104 │
│ 2015-04-01 │          1 │     20309 │     9112 │
│ 2015-07-01 │          0 │     20325 │     4771 │
│ 2015-10-01 │          0 │     25087 │     3030 │
│ 2016-01-01 │          0 │     23462 │     3126 │
│ 2016-04-01 │          3 │     25496 │     2757 │
│ 2016-07-01 │          4 │     28233 │     2928 │
│ 2016-10-01 │          2 │     45445 │     2449 │
│ 2017-01-01 │          9 │     76019 │     2808 │
│ 2017-04-01 │          9 │     67919 │     2803 │
│ 2017-07-01 │         13 │     68974 │     2771 │
│ 2017-10-01 │         12 │     69730 │     2906 │
│ 2018-01-01 │         17 │     67476 │     3152 │
│ 2018-04-01 │          3 │     67139 │     3986 │
│ 2018-07-01 │         14 │     67979 │     3609 │
│ 2018-10-01 │         28 │     74147 │     3850 │
│ 2019-01-01 │         14 │     80250 │     4305 │
│ 2019-04-01 │         30 │     70307 │     3872 │
│ 2019-07-01 │         33 │     77149 │     4164 │
│ 2019-10-01 │         13 │     76746 │     3541 │
│ 2020-01-01 │         16 │     54475 │      846 │
└────────────┴────────────┴───────────┴──────────┘

58 rows in set. Elapsed: 2663.751 sec. Processed 6.74 billion rows, 1.21 TB (2.53 million rows/s., 454.37 MB/s.)
```