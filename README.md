# goodservice-v2

This is a Rails app that generates live route maps, detects headway discrepancies, track delays and compare runtimes to the schedule on the New York City Subway system by comparing the data for live countdown clocks with the static schedule data provided by the MTA.

goodservice-v2 is a re-write of the original [goodservice](https://github.com/blahblahblah-/goodservice) codebase. The goal for this re-write was 1) lower the time to process feed data to be under 30 seconds at all times so that data can be refreshed every 30 seconds instead of every minute, 2) use rolling average of past trips between each pair of stops to predict ETAs of each train to each station, and 3) instead of extracting arrival times like in the past for calculations, we are keep tracking of trips in relation . With these changes, the app no longer uses the concept of lines.

The biggest change is using Redis as the primary persistence source, and relying on [Delayed::Job](https://github.com/collectiveidea/delayed_job) gem and a custom written Heroku Autoscaler to scale horizontally when there are more trains running.

Soon to be live at [https://www.goodservice.io](https://www.goodservice.io/).

## Running locally

To run locally, you'll need a couple things. First, the app has only been tested with Ruby 2.7.2 and Rails 6.1. We suggest managing this with `rbenv`. It also depends on Redis, Postgres, Yarn, and Semantic UI React. If you are on a Mac with Homebrew installed, you can get all these requirements with the following commands:

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

The server performs two major functions: First, it runs a cron job that queues up a delayed job to retrieve new data every 30 seconds, before processing it. THe results are data stored in Redis. This cron job is located in `/lib/clock.rb`.

Second, it serves up data by the cron job with a set of API endpoints. In particular, a Redis cache maintains all the headway info that is served by API (described below). All of the models that are used to process this information live in `/app/models`. `/app/models/redis_store.rb` manages all I/O operations with Redis.

### Client side: React

The client side view libraries are a React app that is compiled by the `webpacker` gem. For more information on `webpacker`, you can see their [repository](https://github.com/rails/webpacker). But the basic summary is that all entry points (in React lingo) live in `/app/javascript/packs` and are compiled to the `/public` directory. As with all Rails apps, this is driven by the views in `/app/views`, which are basically the bare minimum to get the compiled React to appear.

### In the middle: An API

The React front end is fed by an API that Rails serves. The routes are specified in the `/app/controllers` directory. Specifically, dynamically-generated routes are specified in `/config/routes.rb`. The `/api/routes` route is probably most interesting as it drives the main React app.


## Other resources

* [MTA's GTFS-realtime manual](http://datamine.mta.info/sites/all/files/pdfs/GTFS-Realtime-NYC-Subway%20version%201%20dated%207%20Sep.pdf)
* [Most up-to-date MTA static schedule data](http://web.mta.info/developers/developer-data-terms.html)
