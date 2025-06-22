## Command Graph Executor

[![Gem Version](https://badge.fury.io/rb/cge.svg)](http://badge.fury.io/rb/cge) [![Build Status](https://kayla-ci.org/klmcarthur/CGE.svg?branch=master)](https://kayla-ci.org/klmcarthur/CGE) [![Inline docs](http://inch-ci.org/github/klmcarthur/CGE.svg?branch=master)](http://inch-ci.org/github/klmcarthur/CGE) [![Code Climate](https://codeclimate.com/github/klmcarthur/CGE/badges/gpa.svg)](https://codeclimate.com/github/klmcarthur/CGE)


https://rubygems.org/gems/cge

Command Graph Executor, or CGE, is a flexible, extensible system to let a user trigger actions based on events, either on a system or through anything else you can write in Ruby.  Some examples of things you can automate using CGE:

* When my bus is 10 minutes away, text me
* When I get an email from my mother, text me the contents
* When I'm five minutes away from a meeting, send me the agenda
* Automatically create a blog entry based on my tweets
* Automatically download any picture from facebook that has me tagged
* Alert me when the weather changes via text message

In addition, you could use it as a library to develop other action systems, including things like:

* Server monitoring systems
* Email filtering systems

CGE integrates with other action systems such as IFTTT in numerous ways, the easiest probably being through use of Dropbox and monitoring file modification times.  Using CGE with these services permits an even greater level of integration and customizability.

### Planned Features

* Additional plugins for input/output
* A robust Erlang daemon that uses Ruby framework to provide high availability monitor
* Additional input sources (SQL, Socket/Listening API, etc)
* REST API layer

## Contributing

If you're interested in contributing custom actions or monitors you've written, please just submit a pull request - http://github.com/klmcarthur/CGE - and I'll happily have a look.

If you're interested in using CGE in something else, or have a different front-end experience, please let me know as well, for front-ends, I'd love to bring it into the core if it's interesting or useful, and for third party projects I'd love to link to you.

Thanks!
