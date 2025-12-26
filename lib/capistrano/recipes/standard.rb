desc <<-DESC
  Invoke a single command on the remote server. This is useful for performing \
  one-off commands that may not require a full task to be written for them. \
  Simply specify the command to execute via the COMMAND environment variable.

  Sample usage:

    $ cap COMMAND=uptime HOSTS=foo.capistano.test invoke
    $ cap ROLES=app,web SUDO=1 COMMAND="tail -f /var/log/messages" invoke
DESC
task :invoke do
  command = ENV["COMMAND"] || ""
  abort "Please specify a command to execute on the remote servers (via the COMMAND environment variable)" if command.empty?
  invoke_command(command, :via => :run)
end

desc <<-DESC
  Begin an interactive Capistrano session. This gives you an interactive \
  terminal from which to execute tasks and commands on all of your servers. \
  (This is still an experimental feature, and is subject to change without \
  notice!)

  Sample usage:

    $ cap shell
DESC
task :shell do
  require 'capistrano/shell'
  Capistrano::Shell.run(self)
end
