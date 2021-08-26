# goodservice-v2

This is a Rails app that generates live route maps, detects headway discrepancies, track delays and compare runtimes to the schedule on the New York City Subway system by comparing the data for live countdown clocks with the static schedule data provided by the MTA.

goodservice-v2 is a re-write of the original [goodservice](https://github.com/blahblahblah-/goodservice) codebase. The goal for this re-write was 1) reduce the time to process feed data to be under 30 seconds at all times, so that data can be refreshed in shorter intervals instead of every minute (data is refreshed every 15 seconds in production), 2) use rolling average of past trips between each pair of stops to predict ETAs of each train to each station, and 3) instead of extracting arrival times in the past for headway calculations, we are keeping track of trips in relation each other in order to figure out the time between trains. With these changes, the app no longer uses the concept of lines, and train arrival times are now available to view via lookup by station.

The biggest change in technology use is using Redis as the primary persistence source, relying on [Sidekiq](https://github.com/mperham/sidekiq) to process data asynchronously, using [sidekiq-cron](https://github.com/ondrejbartas/sidekiq-cron) to schedule jobs and a custom written [Heroku Autoscaler](https://github.com/blahblahblah-/goodservice-v2/blob/main/app/workers/heroku_autoscaler_worker.rb) to scale horizontally when there are more trains running and the job queue is getting too large. Postgres is still used to store static schedule info.

See it live at [https://www.goodservice.io](https://www.goodservice.io/). The same set of APIs are used to power [https://www.theweekendest.com](https://www.theweekendest.com/)

## Running locally

To run locally, you'll need a couple things. First, the app requires Ruby 2.7.2 and Rails 6.1. We suggest managing this with `rbenv`. It also depends on Redis, Postgres, Yarn, and Semantic UI React. If you are on a Mac with Homebrew installed, you can get all these requirements with the following commands:

```
# Ruby dependencies
brew install rbenv
brew install ruby-build
rbenv install 2.7.2
gem install bundler

# Other dependencies
brew install postgresql
brew install redis
brew install node
npm install -g yarn
```

Next, you'll need to sign up for a developer account with the MTA. To do so, go to [https://api.mta.info](https://api.mta.info). You'll get an API key and set it as `MTA_KEY` env variable.

Finally, you'll need to download the current static schedules from the MTA. Go to [https://web.mta.info/developers/developer-data-terms.html](https://web.mta.info/developers/developer-data-terms.html), agree to the terms, and then download the data for New York City Transit. (Ctrl+F for "GTFS".) Put this into the `import` folder and unzip it.

Finally, to run the app locally, do

```
export MTA_KEY=<<YOUR API KEY>>
bundle install
yarn install
initdb
rails db:reset  # This will take a *very* long time on its first run
rails db:seed
rails db:migrate
foreman start -f Procfile
```

## A brief tour of the code

This is a Rails app that uses React as a view manager. As such, there are a lot of moving components. We briefly explain how data flows and how the code is laid out.

### Server side: Rails

Regularly occuring jobs are scheduled with [sidekiq-cron](https://github.com/ondrejbartas/sidekiq-cron), and are defined in the [Sidekiq initializer](https://github.com/blahblahblah-/goodservice-v2/blob/main/config/initializers/sidekiq.rb).

The order of operation to process the feeds within the every 15 seconds cycle is:
FeedRetrieverSpawningWorker > FeedRetrieverWorker > FeedProcessorWorker > FeedProcessor > RouteProcessor > RouteAnalyzer

Static schedule data is stored in Postgres and their associated ActiveRecord classes are in the `Scheduled` namespace. No other data is currently stored in Postgres.

The primary persistence source is Redis. The class [`RedisStore`](https://github.com/blahblahblah-/goodservice-v2/blob/main/app/models/redis_store.rb) provides the interfaces used to interact with the Redis client.

### Client side: React

The client side view libraries are a React app that is compiled by the `webpacker` gem. For more information on `webpacker`, you can see their [repository](https://github.com/rails/webpacker). But the basic summary is that all entry points (in React lingo) live in `/app/javascript/packs` and are compiled to the `/public` directory. As with all Rails apps, this is driven by the views in `/app/views`, which are basically the bare minimum to get the compiled React to appear.

### In the middle: An API

The React front end is fed by an API that Rails serves. The routes are specified in the `/app/controllers/api` directory. Specifically, dynamically-generated routes are specified in `/config/routes.rb`. There are only 2 endpoints for now, and they're both in the Api::RoutesController class, which serve the data as `/api/routes`

## Supported external services

### Twitter

The `TwitterDelaysNotifierWorker` job to used to check if there are currently delays. If so, notifications are sent on Twitter. Make sure the env variables `TWITTER_ACCESS_TOKEN`, `TWITTER_ACCESS_TOKEN_SECRET`, `TWITTER_CONSUMER_KEY`, `TWITTER_CONSUMER_SECRET` are populated.

### Alexa

See [goodservice-ask](https://github.com/blahblahblah-/goodservice-ask).

### Google Assistant

See [goodservice-gactions](https://github.com/blahblahblah-/goodservice-gactions).

## Other resources

* [MTA's GTFS-realtime manual](http://datamine.mta.info/sites/all/files/pdfs/GTFS-Realtime-NYC-Subway%20version%201%20dated%207%20Sep.pdf)
* [Most up-to-date MTA static schedule data](http://web.mta.info/developers/developer-data-terms.html)

## Inspirations

* [DC MetroHero](https://dcmetrohero.com)
* [NYC Subway Stringlines](https://pvibien.com/stringline.htm)
