## 2.2.0
  - Upgraded the twitter gem to the last version available, 5.15.0
  - Add proxy support, Fixes #7.

## 2.1.0
  - Add an option to fetch data from the sample endpoint.
  - Add hashtags, symbols and user_mentions as data for the non extended tweet event.
  - Add an option to filter per location and language.
  - Add an option to stream data from a list of users.
  - Add integration and unit tests for this and previous features.
  - Add an ignore_retweet flag to filter them.
  - Small code reorg and refactoring.
  - Fixes #22 #21 #20 #11 #9

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully, 
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

1.0.1
  * Handle tweets with a null 'in-reply-to' without crashing. This is a temporary fix till JrJackson is updated.
