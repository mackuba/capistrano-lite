## Capistrano Lite

Capistrano Lite is a simplified fork of Capistrano 2 focused on deploying a
single Ruby application to a single host over SSH. It keeps the core deploy
DSL, the git remote cache and copy strategies, release rotation with rollbacks,
and the logging/formatting you expect while stripping away roles, stages,
gateways, plugins, and legacy SCMs.

## Documentation

* [https://github.com/capistrano/capistrano/wiki](https://github.com/capistrano/capistrano/wiki)

## DEPENDENCIES

* [Net::SSH](http://net-ssh.rubyforge.org)
* [Net::SFTP](http://net-ssh.rubyforge.org)
* [Net::SCP](http://net-ssh.rubyforge.org)
* [HighLine](http://highline.rubyforge.org)
* [Ruby](http://www.ruby-lang.org/en/) &#x2265; 2.6

If you want to run the tests, you'll also need to install the dependencies with
Bundler, see the `Gemfile` within .

## ASSUMPTIONS

Capistrano is "opinionated software", which means it has very firm ideas about
how things ought to be done, and tries to force those ideas on you. Some of the
assumptions behind these opinions are:

* You are using SSH keys to access the remote server.
* You deploy from git (remote_cache by default) or copy the project archive.
* You are deploying to a single host with a single `config/deploy.rb` file.

## USAGE

In general, you'll use Capistrano Lite as follows:

* Create a `config/deploy.rb` with your settings.
* Use the `cap` script to execute your recipe.

Use the `cap` script as follows:

    cap deploy

Capistrano Lite loads `config/deploy.rb` directly and does not use a Capfile or
stages. A minimal configuration looks like:

```ruby
set :application, "bluefeeds"
set :repository, "git@github.com:mackuba/bluefeeds.git"
set :server, "blue.mackuba.eu"
```

The default deploy path is `/var/www/#{application}`, the default strategy is
`remote_cache`, and cleanup of old releases runs automatically after each
deploy.

## CONTRIBUTING:

* Fork Capistrano
* Create a topic branch - `git checkout -b my_branch`
* Rebase your branch so that all your changes are reflected in one
  commit
* Push to your branch - `git push origin my_branch`
* Create a Pull Request from your branch, include as much documentation
  as you can in the commit message/pull request, following these
[guidelines on writing a good commit message](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
* That's it!


## LICENSE:

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
