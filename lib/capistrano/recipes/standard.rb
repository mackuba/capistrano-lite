# frozen_string_literal: true

desc <<-DESC
  Invoke a single command on the remote server. This is useful for performing \
  one-off commands that may not require a full task to be written for them. \
  Simply specify the command to execute via the COMMAND environment variable. \
  To temporarily replace the configured server, specify the HOST environment \
  variable. Lastly, if you want to \
  execute the command via sudo, specify a non-empty value for the SUDO \
  environment variable.

  Sample usage:

    $ cap COMMAND=uptime HOST=foo.capistano.test invoke
    $ cap HOST=app1.example.com SUDO=1 COMMAND="tail -f /var/log/messages" invoke
DESC
task :invoke do
  command = ENV["COMMAND"] || ""
  abort "Please specify a command to execute on the remote server (via the COMMAND environment variable)" if command.empty?
  method = ENV["SUDO"] ? :sudo : :run
  invoke_command(command, :via => method)
end
