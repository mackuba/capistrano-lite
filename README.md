## Capistrano

[![Build
Status](https://secure.travis-ci.org/capistrano/capistrano.png)](http://travis-ci.org/capistrano/capistrano)[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/capistrano/capistrano)


Capistrano is a utility and framework for executing commands on a remote
machine, via SSH. It uses a simple DSL (borrowed in part from
[Rake](http://rake.rubyforge.org/)) that allows you to define _tasks_.

Capistrano was originally designed to simplify and automate deployment of web
applications to distributed environments, and originally came bundled with a set
of tasks designed for deploying Rails applications.

## Documentation

* [https://github.com/capistrano/capistrano/wiki](https://github.com/capistrano/capistrano/wiki)

## DEPENDENCIES

* [Net::SSH](http://net-ssh.rubyforge.org)
* [Net::SFTP](http://net-ssh.rubyforge.org)
* [Net::SCP](http://net-ssh.rubyforge.org)
* [HighLine](http://highline.rubyforge.org)
* [Ruby](http://www.ruby-lang.org/en/) &#x2265; 1.8.7

If you want to run the tests, you'll also need to install the dependencies with
Bundler, see the `Gemfile` within .

## ASSUMPTIONS

Capistrano is "opinionated software", which means it has very firm ideas about
how things ought to be done, and tries to force those ideas on you. Some of the
assumptions behind these opinions are:

* You are using SSH to access the remote server.
* You have public keys in place for SSH access.

Do not expect these assumptions to change.

## USAGE

In general, you'll use Capistrano as follows:

* Create a recipe file ("capfile" or "Capfile").
* Use the `cap` script to execute your recipe.

Use the `cap` script as follows:

    cap sometask

By default, the script will look for a file called one of `capfile` or
`Capfile`. The `sometask` text indicates which task to execute. You can do
"cap -h" to see all the available options and "cap -T" to see all the available
tasks.

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
