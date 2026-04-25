# Capistrano `lib` Codebase Map

This document maps the files under `lib/`, the classes/modules they define, what they are for, and the main internal dependencies between them.

## High-Level Shape

Capistrano is centered on `Capistrano::Configuration`. The root file loads the configuration DSL, extension/plugin support, and a small `String` helper. `Configuration` mixes in modules for variables, task namespaces, callbacks, single-server selection, recipe loading, SSH connection management, command execution, file transfer, and inspection helpers.

Built-in recipes live under `lib/capistrano/recipes`. The deploy recipe composes two plugin families:

- `Capistrano::Deploy::SCM`: source control adapters that return shell commands. This tree currently keeps only Git and the no-SCM local-copy adapter.
- `Capistrano::Deploy::Strategy`: deployment strategies that execute SCM commands locally or remotely.

## File Inventory

| File | Classes/modules defined | Purpose | Main internal dependencies |
| --- | --- | --- | --- |
| `lib/capistrano.rb` | none directly | Main library entry point. Loads the configuration DSL, plugin extension system, and string helper. | `configuration`, `extensions`, `ext/string` |
| `lib/capistrano/callback.rb` | `Capistrano::Callback`, `ProcCallback`, `TaskCallback` | Represents callbacks registered around task lifecycle events. `ProcCallback` calls a block, `TaskCallback` executes another Capistrano task and prevents direct self-recursion. | Used by `configuration/callbacks` |
| `lib/capistrano/cli.rb` | `Capistrano::CLI` | Command-line facade that stores raw args and mixes in parsing, execution, UI, and help behavior. | `capistrano`, `cli/execute`, `cli/help`, `cli/options`, `cli/ui` |
| `lib/capistrano/cli/execute.rb` | `Capistrano::CLI::Execute` | Turns parsed options into a `Configuration`, loads recipes, fires lifecycle hooks, executes requested actions, and handles top-level errors. | `configuration`; calls `Configuration`, `Callbacks`, task execution |
| `lib/capistrano/cli/help.rb` | `Capistrano::CLI::Help` | Overrides CLI action execution for `-T` task listing and `-e` task explanation. Formats long help text. | Mixed into `CLI`; uses `TaskDefinition` data through `Configuration#task_list` and `#find_task` |
| `lib/capistrano/cli/help.txt` | none | ERB-like help text used by `CLI::Help#long_help`. | Read by `cli/help` |
| `lib/capistrano/cli/options.rb` | `Capistrano::CLI::Options` | Defines `OptionParser` switches, default config discovery, environment variable extraction, and simple value coercion for `-s` and `-S`. | Mixed into `CLI`; requires `optparse`; uses `Logger`, `Version`, `CLI.password_prompt` |
| `lib/capistrano/cli/ui.rb` | `Capistrano::CLI::UI` | HighLine integration for password prompts, debug command confirmation, terminal dimensions, and paging. | `highline`; used by `cli/options`, `configuration/actions/invocation`, SCM adapters |
| `lib/capistrano/command.rb` | `Capistrano::Command` | Single-session remote command runner. Opens one SSH command channel, handles stdout/stderr callbacks, optional pty, environment injection, placeholder replacement, and remote command errors. | `errors`, `processable`, `Configuration.default_io_proc`, SSH session from `connections` |
| `lib/capistrano/configuration.rb` | `Capistrano::Configuration` | Central DSL object. Owns logger/debug/dry-run state, initializes the logger, mixes in all configuration and action modules, and unblocks namespace method shadowing. | `logger`; all `configuration/*`; `configuration/actions/*` |
| `lib/capistrano/configuration/actions/file_transfer.rb` | `Capistrano::Configuration::Actions::FileTransfer` | Adds `put`, `get`, `upload`, `download`, and `transfer` DSL actions. Delegates actual work to `Capistrano::Transfer`. | `transfer`, `Connections#execute_on_server`, `Connections#session`, `run` |
| `lib/capistrano/configuration/actions/inspect.rb` | `Capistrano::Configuration::Actions::Inspect` | Adds `stream` and `capture` actions for running commands and consuming streamed or captured single-server output. | `errors`, `Invocation#invoke_command`, `sudo` |
| `lib/capistrano/configuration/actions/invocation.rb` | `Capistrano::Configuration::Actions::Invocation` | Adds `run`, `invoke_command`, `sudo`, command defaults, sudo prompt handling, and debug prompting. Converts DSL command calls into sequential `Command` execution. | `command`, `Servers#active_server`, `Connections#execute_on_server`, `CLI.debug_prompt`, `Variables` |
| `lib/capistrano/configuration/alias_task.rb` | `Capistrano::Configuration::AliasTask` | Adds `alias_task`, duplicating an existing task under a new name. | `Namespaces#find_task`, `#define_task`, `NoSuchTaskError` |
| `lib/capistrano/configuration/callbacks.rb` | `Capistrano::Configuration::Callbacks` | Adds task lifecycle hooks: `before`, `after`, `on`, `trigger`. Wraps task invocation so callbacks fire around every direct task call. | `callback`, `Execution#invoke_task_directly`, `Execution#find_and_execute_task` |
| `lib/capistrano/configuration/connections.rb` | `Capistrano::Configuration::Connections` | Manages the single SSH session, connection failure state, single-server connection establishment/teardown, and continuing after remote errors where requested. | `ssh`, `errors`, `Servers#active_server`, `Execution#current_task` |
| `lib/capistrano/configuration/execution.rb` | `Capistrano::Configuration::Execution`, `TaskCallFrame` | Runs tasks, tracks the current task stack, implements transactions and `on_rollback`, and locates/executes tasks by name. | `errors`, `Namespaces`, `Callbacks` |
| `lib/capistrano/configuration/loading.rb` | `Capistrano::Configuration::Loading`, `Loading::ClassMethods` | Loads recipes from files, strings, or procs. Provides a Capistrano-aware `require` that lets multiple configuration instances reload recipe DSL effects. | Used by `CLI::Execute`, recipes, extensions |
| `lib/capistrano/configuration/log_formatters.rb` | `Capistrano::Configuration::LogFormatters` | DSL for adding logger formatters and disabling formatting. | `logger` |
| `lib/capistrano/configuration/namespaces.rb` | `Capistrano::Configuration::Namespaces`, `Namespaces::Namespace`, `Kernel.method_added` hook | Implements `namespace`, `task`, `desc`, task lookup, namespace lookup, default tasks, and nested namespace forwarding to parent configuration. | `task_definition`, `alias_task`, `execution` |
| `lib/capistrano/configuration/servers.rb` | `Capistrano::Configuration::Servers` | Adds the single-host `server` DSL and resolves the configured server, with `HOST` as a one-host environment override. | `ServerDefinition`, `errors` |
| `lib/capistrano/configuration/variables.rb` | `Capistrano::Configuration::Variables` | Configuration variables with lazy proc evaluation, reset/unset, `fetch`, `[]`, and variable-backed `method_missing`. | Used by nearly every DSL and recipe file |
| `lib/capistrano/errors.rb` | `Capistrano::Error`, `CaptureError`, `NoSuchTaskError`, `NoMatchingServersError`, `RemoteError`, `ConnectionError`, `TransferError`, `CommandError`, `LocalArgumentError` | Shared exception hierarchy. Remote errors carry affected hosts. | Used by command, transfer, connections, execution, recipes, deploy adapters |
| `lib/capistrano/ext/string.rb` | reopens `String` | Adds `String#compact`, collapsing whitespace. Used to make heredoc shell commands one line. | Used by deploy assets and recipe command heredocs |
| `lib/capistrano/extensions.rb` | `Capistrano::ExtensionProxy`, `Capistrano::EXTENSIONS`, plugin methods | Plugin registration system. Adds proxy methods to `Configuration` instances and delegates unknown plugin method calls back to the configuration. | `Configuration`, `Error` |
| `lib/capistrano/logger.rb` | `Capistrano::Logger` | Level-based logger with TTY color/style formatters, timestamp/prepend/append/replace support, and default formatter registration. | Used by `Configuration`, CLI options, command/transfer/strategy/scm code |
| `lib/capistrano/processable.rb` | `Capistrano::Processable`, `Processable::SessionAssociation` | Shared single-session Net::SSH event loop helper. Preprocesses/postprocesses the session with `IO.select` and associates raised errors with that session. | Included by `Command`, `Transfer` |
| `lib/capistrano/recipes/deploy.rb` | recipe methods and tasks only | Primary deployment recipe. Defines deploy variables, helpers (`scm_default`, `depend`, `with_env`, `run_locally`, `try_sudo`, `try_runner`), and tasks for setup, update, update_code, symlinks, upload, rollback, migrations, cleanup, checks, cold deploy, start/stop, pending diff/log, and web maintenance mode. Defaults to Git when `.git` exists and `none` otherwise. | `deploy/scm`, `deploy/strategy`, `dependencies`, `Command`/`Transfer` through configuration actions |
| `lib/capistrano/recipes/deploy/assets.rb` | recipe methods and tasks only | Rails asset-pipeline extension. Hooks into deploy lifecycle to symlink shared assets, precompile, maintain manifest mtimes, clean expired assets, clean all assets, and roll back manifests. | Loads `deploy`; `json`, `yaml` via deploy, `Set` via deploy, `String#compact`, callbacks/tasks/actions |
| `lib/capistrano/recipes/deploy/dependencies.rb` | `Capistrano::Deploy::Dependencies` | Aggregates local and remote dependency checks and reports pass/fail. | `local_dependency`, `remote_dependency` |
| `lib/capistrano/recipes/deploy/local_dependency.rb` | `Capistrano::Deploy::LocalDependency` | Checks local command availability in `PATH`. | Used by `Dependencies`, `Strategy::Copy#check!` |
| `lib/capistrano/recipes/deploy/remote_dependency.rb` | `Capistrano::Deploy::RemoteDependency` | Checks remote directories, files, writability, commands, gems, deb/rpm packages, and expected command output. | `errors`, `Configuration#invoke_command`, `CommandError` |
| `lib/capistrano/recipes/deploy/scm.rb` | `Capistrano::Deploy::SCM` | Factory module for dynamic SCM adapter loading by name. | Dynamic requires `deploy/scm/<name>`; raises `Capistrano::Error` |
| `lib/capistrano/recipes/deploy/scm/base.rb` | `Capistrano::Deploy::SCM::Base`, `Base::LocalProxy` | Abstract SCM adapter API. Provides local-mode variable lookup, command construction, default command handling, logging, and abstract checkout/sync/diff/log/query hooks. | `Configuration` variables and logger; subclassed by all SCM adapters |
| `lib/capistrano/recipes/deploy/scm/git.rb` | `Capistrano::Deploy::SCM::Git` | Git adapter. Supports clone/export/sync, branches/remotes, shallow clones, submodules, diff/log, SHA resolution, and prompt responses for passwords, passphrases, host keys, and certs. | `scm/base`, `CLI.password_prompt` |
| `lib/capistrano/recipes/deploy/scm/none.rb` | `Capistrano::Deploy::SCM::None` | Non-SCM adapter for copying a local directory. Intended for `deploy_via :copy`; no real history support. | `scm/base` |
| `lib/capistrano/recipes/deploy/strategy.rb` | `Capistrano::Deploy::Strategy` | Factory module for dynamic deploy strategy loading by name. | Dynamic requires `deploy/strategy/<name>`; raises `Capistrano::Error` |
| `lib/capistrano/recipes/deploy/strategy/base.rb` | `Capistrano::Deploy::Strategy::Base` | Abstract deployment strategy API. Provides deploy check defaults, configuration method delegation, local `system` logging, and real revision access. | `deploy/dependencies`, `logger`, `Configuration` DSL |
| `lib/capistrano/recipes/deploy/strategy/copy.rb` | `Capistrano::Deploy::Strategy::Copy`, `Copy::Compression` | Local-copy strategy. Checks out/export locally or refreshes a local cache, optionally builds, excludes files, archives, uploads, extracts remotely, and cleans staging artifacts. | `strategy/base`, `fileutils`, `tempfile`, `LocalDependency`, `FileTransfer#upload`, SCM local proxy |
| `lib/capistrano/recipes/deploy/strategy/remote_cache.rb` | `Capistrano::Deploy::Strategy::RemoteCache` | Remote strategy maintaining a shared cached checkout under `shared_path`, then copying/rsyncing it to each release. Handles SCM prompt filtering and writes `REVISION`. | `strategy/base`, SCM `sync`/`checkout`/`handle_data`, remote `rsync` when exclusions exist |
| `lib/capistrano/recipes/standard.rb` | recipe tasks only | Standard recipe loaded by CLI. Defines `invoke` for one-off remote commands. | `configuration/actions/invocation` |
| `lib/capistrano/recipes/templates/maintenance.rhtml` | none | ERB/XHTML maintenance-page template used by `deploy:web:disable`. | Read by `recipes/deploy.rb` |
| `lib/capistrano/server_definition.rb` | `Capistrano::ServerDefinition` | Parses and stores `user@host:port` plus server options. Provides comparison, equality/hash, default user, and string rendering. | Used by `Servers`, `SSH`, `Connections` |
| `lib/capistrano/ssh.rb` | `Capistrano::SSH`, `SSH::Server` | SSH connection helper. Applies the originating `ServerDefinition` to the Net::SSH session and builds public-key-only connection options. | `net/ssh`, `ServerDefinition` |
| `lib/capistrano/task_definition.rb` | `Capistrano::TaskDefinition` | Stores task metadata: name, namespace, options, body, description, and rollback behavior. Formats descriptions and computes fully qualified names. | `server_definition`; used by `configuration/namespaces` and `execution` |
| `lib/capistrano/transfer.rb` | `Capistrano::Transfer`, `Transfer::SFTPTransferWrapper` | Single-session upload/download engine over SFTP or SCP. Normalizes host placeholders and IOs, tracks transfer failure, delegates event processing to `Processable`, and raises `TransferError`. | `net/scp`, `net/sftp`, `processable`, `errors`, SSH session |
| `lib/capistrano/version.rb` | `Capistrano::Version`, `Capistrano::VERSION` | Version constants and string rendering for Capistrano 2.15.11. | Used by CLI `--version` |

## Dependency Graph

This graph shows the main internal runtime clusters rather than every standard-library require.

Saved image: [docs/lib-dependency-graph.svg](lib-dependency-graph.svg)

```mermaid
flowchart TD
  root["lib/capistrano.rb"] --> config["Capistrano::Configuration"]
  root --> extensions["Capistrano.plugin / ExtensionProxy"]
  root --> string_ext["String#compact"]

  cli["Capistrano::CLI"] --> config
  cli --> cli_execute["CLI::Execute"]
  cli --> cli_options["CLI::Options"]
  cli --> cli_help["CLI::Help"]
  cli --> cli_ui["CLI::UI"]

  config --> variables["Configuration::Variables"]
  config --> namespaces["Configuration::Namespaces"]
  config --> execution["Configuration::Execution"]
  config --> callbacks["Configuration::Callbacks"]
  config --> servers_mod["Configuration::Servers"]
  config --> loading["Configuration::Loading"]
  config --> connections["Configuration::Connections"]
  config --> invocation["Actions::Invocation"]
  config --> transfer_actions["Actions::FileTransfer"]
  config --> inspect_actions["Actions::Inspect"]
  config --> log_formatters["Configuration::LogFormatters"]

  namespaces --> task_definition["TaskDefinition"]
  servers_mod --> server_definition["ServerDefinition"]
  connections --> ssh["SSH"]
  connections --> errors["Errors"]
  invocation --> command["Command"]
  transfer_actions --> transfer["Transfer"]
  command --> processable["Processable"]
  transfer --> processable
  callbacks --> callback_classes["Callback / ProcCallback / TaskCallback"]
  execution --> callbacks
  execution --> namespaces

  deploy_recipe["recipes/deploy.rb"] --> scm_factory["Deploy::SCM factory"]
  deploy_recipe --> strategy_factory["Deploy::Strategy factory"]
  deploy_recipe --> config
  assets_recipe["recipes/deploy/assets.rb"] --> deploy_recipe

  scm_factory --> scm_base["SCM::Base"]
  scm_base --> scm_adapters["Git, None"]
  strategy_factory --> strategy_base["Strategy::Base"]
  strategy_base --> dependencies["Deploy::Dependencies"]
  dependencies --> local_dep["LocalDependency"]
  dependencies --> remote_dep["RemoteDependency"]
  strategy_base --> strategies["Copy, RemoteCache"]
  strategies --> scm_adapters
  strategies --> config
```

## Static/Internal Require And Load Dependencies

These are the code-level edges visible from `require` and `load`, excluding Ruby standard-library and gem dependencies unless they are important to the file's role.

| File | Internal files loaded directly |
| --- | --- |
| `lib/capistrano.rb` | `capistrano/configuration`, `capistrano/extensions`, `capistrano/ext/string` |
| `lib/capistrano/cli.rb` | `capistrano`, `capistrano/cli/execute`, `capistrano/cli/help`, `capistrano/cli/options`, `capistrano/cli/ui` |
| `lib/capistrano/cli/execute.rb` | `capistrano/configuration` |
| `lib/capistrano/cli/options.rb` | dynamically `capistrano/version` for `--version` |
| `lib/capistrano/command.rb` | `capistrano/errors`, `capistrano/processable` |
| `lib/capistrano/configuration.rb` | `capistrano/logger`; all `capistrano/configuration/*`; all `capistrano/configuration/actions/*` |
| `lib/capistrano/configuration/actions/file_transfer.rb` | `capistrano/transfer` |
| `lib/capistrano/configuration/actions/inspect.rb` | `capistrano/errors` |
| `lib/capistrano/configuration/actions/invocation.rb` | `capistrano/command` |
| `lib/capistrano/configuration/callbacks.rb` | `capistrano/callback` |
| `lib/capistrano/configuration/connections.rb` | `capistrano/ssh`, `capistrano/errors` |
| `lib/capistrano/configuration/execution.rb` | `capistrano/errors` |
| `lib/capistrano/configuration/namespaces.rb` | `capistrano/task_definition` |
| `lib/capistrano/configuration/servers.rb` | `capistrano/server_definition`, `capistrano/errors` |
| `lib/capistrano/recipes/deploy.rb` | `capistrano/recipes/deploy/scm`, `capistrano/recipes/deploy/strategy` |
| `lib/capistrano/recipes/deploy/assets.rb` | `load 'deploy'` unless `_cset` already exists |
| `lib/capistrano/recipes/deploy/dependencies.rb` | `capistrano/recipes/deploy/local_dependency`, `capistrano/recipes/deploy/remote_dependency` |
| `lib/capistrano/recipes/deploy/remote_dependency.rb` | `capistrano/errors` |
| `lib/capistrano/recipes/deploy/scm.rb` | dynamically `capistrano/recipes/deploy/scm/<name>` |
| `lib/capistrano/recipes/deploy/scm/git.rb` | `capistrano/recipes/deploy/scm/base` |
| `lib/capistrano/recipes/deploy/scm/none.rb` | `capistrano/recipes/deploy/scm/base` |
| `lib/capistrano/recipes/deploy/strategy.rb` | dynamically `capistrano/recipes/deploy/strategy/<name>` |
| `lib/capistrano/recipes/deploy/strategy/base.rb` | `capistrano/recipes/deploy/dependencies` |
| `lib/capistrano/recipes/deploy/strategy/remote_cache.rb` | `capistrano/recipes/deploy/strategy/base` |
| `lib/capistrano/recipes/deploy/strategy/copy.rb` | `capistrano/recipes/deploy/strategy/base` |
| `lib/capistrano/task_definition.rb` | `capistrano/server_definition` |
| `lib/capistrano/transfer.rb` | `capistrano/processable` |

## Runtime Usage Notes

- `Configuration` is the central dependency hub. Most recipe and strategy code calls into it through DSL methods mixed in from its modules.
- `Command` and `Transfer` depend on `Processable` because they share the same single-session Net::SSH event-loop pattern.
- `ServerDefinition` is the single configured server identity object. It carries host/user/port/options into the `HOST` override path, SSH connection setup, command placeholders, transfer logging, and error reporting.
- `Callbacks` wraps `Execution#invoke_task_directly`; task lifecycle hooks therefore apply to all direct task execution paths, including CLI actions and recipe-invoked task aliases.
- `Deploy::SCM` and `Deploy::Strategy` are factories. They load adapter files by name and instantiate classes from generated constant names.
- SCM adapters generally do not execute commands. They return shell command strings and prompt handlers. Strategies decide whether those commands run locally, remotely, through caches, or through uploaded archives.
- `Strategy::Copy` is the main bridge from local SCM commands to remote deployment: it uses the SCM's local proxy, local filesystem staging, compression utilities, `upload`, and remote decompression.
- `recipes/deploy/assets.rb` is not a class extension. It is a recipe that mutates the current configuration by setting defaults, registering callbacks, adding helper methods, and defining `deploy:assets:*` tasks.
