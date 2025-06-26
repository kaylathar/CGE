## Command Graph Executor

Command Graph Executor is an action graph execution system that allows users to specify specific graphs of behaviors they want to have executed, similar to something like IFTTT or Zapier but self-hosted and with in many cases fewer integrations that you have more control over.

For example you could setup workflows supporting:
* When my bus is 10 minutes away, text me
* If a webhook is triggered, then if it has the contexts X, text me, wait for a response, then send that text to this other backend

Graphs of multiple types of commands are supported - this can include waiting on multiple things, conditional comparisons, and much more.

## Planned Features

* Additional action, input, conditional, and monitor types for a variety of services
* Web and Mobile apps to interact with the server via a RESTful API
* More robust daemon
* Some base Service types to support use cases such as dynamically configurable Discord or Slack bots that easily integrate with other systems, or other more dynamic applications

## Contributing

If you're interested in contributing custom commands you've written, please just submit a pull request - http://github.com/klmcarthur/CGE - and I'll happily have a look.
