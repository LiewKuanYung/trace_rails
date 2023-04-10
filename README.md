# Trace Rails

Trace events happened while running rails server. It will listen and record events data for every single route (from REQUEST to RESPONSE). Currently, the events included are `:call` and `:line`.

# Setup 

1. Checkout to a new branch `git checkout -b try/trace-rails`
2. Copy this folder into `./lib` folder. It should be something like this:
   ```
   root
   ├── app
   └── lib
       └── trace_rails
           ├── README.md # You're now reading this
           ├── data
           ├── tracer.rb
           ├── tracer_middleware.rb
           └── tracer_logger.rb
   ```

3. Add `config.middleware.use TracerMiddleware` into `config/application.rb`. However this will result error due to middleware not found. To fix this, just import `require_relative '../lib/trace_rails/tracer_middleware'` at the top of `config/application.rb`.

4. Install the following gems **locally** (not in Gemfile)
   * [Rainbow](https://github.com/sickill/rainbow), a ruby gem for colorizing printed text on ANSI terminals.
     Run `gem install rainbow`
   * (OPTIONAL) [method_source](https://github.com/banister/method_source), to retrieve the sourcecode for a method.
     Run `gem install method_source`

# Start

1. After finished #Setup, start the server using `rails server`. 
   Reminder note: if you have any other background job, you need to run it on other terminal, it doesn't work well will `foreman start -f Procfile.dev`

2. Then visit any page you like. 

3. You can view the result in 2 places:
   * Terminal. The terminal will give you an overall report of what methods being called.
   * `/data/`. JSON data stored here represents sequencial data of what methods being called. It will store the previous 5 or 3 routes ran in your server. (configurable at `TracerCollector::CALLS_LIMIT` or `TracerCollector::LINES_LIMIT`)
     * `/data/calls.json` stores method called data.
     * `/data/lines.json` stores line executed data.

# Configurable

Reminder: Middlewares are loaded once and are not monitored for changes. You will have to restart the server for changes to be reflected in the running application. See [rails documentation](https://guides.rubyonrails.org/rails_on_rack.html#development-and-auto-reloading) for more details.

1. `@opts` inside `tracer_middlware.rb` is configuration options for event type tracing and data format.

2. `CALLS_LIMIT`, `LINES_LIMIT`, and `CALLER_LIMIT` inside `TracerCollector` set the limit for data stored in `data/`.

# Remarks

Apologize that many of the details are not documented clearly. This is just a side project used to learn middlware, and design patterns like collector and singleton. However, please feel very free to ping me if you have any question and wanna provide any suggestion. Thanks :)
