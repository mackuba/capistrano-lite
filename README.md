# Capistrano Lite

Capistrano Lite (temporary name) is a simplified fork of old [Capistrano](https://github.com/capistrano/capistrano) 2.x.


## Project description

Capistrano Lite is a tool for deploying Ruby applications to a server, based on the code of the classic deploy tool Capistrano, the older 2.x version, but simplified and cleaned up, with various features removed that I decided I'm never going to need myself. The focus is on deploying Ruby apps to a single host from Git over SSH. It keeps the core deploy DSL with compatibility maintained where possible, the git remote cache and copy strategies, release rotation with rollbacks, and the logging/formatting code.


### What is removed

* server roles, multiple servers and "primary" server designation – you only define a single server hostname and everything happens there
* support for any parallel execution
* multiple stages
* SSH gateways
* password authentication for SSH and Git
* Windows support
* REPL shell
* legacy SCMs – only `:git` and `:none` are left
* most deploy strategies – only `:remote_cache` and `:copy` are left
* any legacy/deprecated code from Capistrano 1.x era or for ancient versions of Ruby


### Other API changes

* default deploy path is `/var/www/#{application}`
* `server` method in the DSL only accepts a single string + options
* Ruby 3.0+ is required


### Project status

> [!WARNING]
> This project is an early, untested alpha version. Most of the work stripping out various parts from the old codebase was done using Codex AI coding agent (with manual code reviews to some degree). Use with caution.
