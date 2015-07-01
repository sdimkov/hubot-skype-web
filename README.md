hubot-skype-web
===============

A [Skype](http://www.skype.com/) adapter for [Hubot](https://hubot.github.com/) that connects via Skype web.

[![Version](https://img.shields.io/npm/v/hubot-skype-web.svg)](https://github.com/anroots/hubot-skype-web/releases)
[![Licence](https://img.shields.io/npm/l/express.svg)](https://github.com/anroots/hubot-skype-web/blob/master/LICENSE)
[![Downloads](https://img.shields.io/npm/dm/hubot-skype-web.svg)](https://www.npmjs.com/package/hubot-skype-web)

This adapter allows integrating your Hubot with Skype.

Available functionality:
* Sending / Receiving messages in personal chats with contacts
* Sending / Receiving messages in group chats with anyone in the group (non-contacts included)

What's missing:
* Sending / Accepting / Rejecting contact requests
* Sending / Receiving of files
* Recognizing contact presense (appearing online ; going offline..etc)

Also note that this adapter can not connect to the old P2P group chats. That's a general limitation of Skype's web offerings as it does not go through Skype's servers. Read more about cloud-based and P2P-based Skype groups [here](https://support.skype.com/en/faq/FA12381/what-is-the-cloud)

Configuration
-------------

This adapter can only be configured via Environment variables.

Mandatory Environment variables:
* `HUBOT_SKYPE_USERNAME` _String_ - hubot's skype account username
* `HUBOT_SKYPE_PASSWORD` _String_ - hubot's skype account password in plain text

Optional Environment variables:
* `HUBOT_SKYPE_RECONNECT` _Integer_ - The duration between reconnects in minutes. Minimal value is 20. I would recommend 240. Reconnect does not disturb hubot's uptime.
* `HUBOT_LOG_LEVEL` _String [debug|info|notice|warning|error|critical|alert|emergency], default: info_ - Set the log level of Hubot. The Fleep adapter can output extensive debug messages.

Contributing
------------

Patches are welcome. Browse the [documentation](https://cdn.rawgit.com/sdimkov/hubot-skype-web/v0.9.3/doc/index.html) to get started.

Licence
-------

The MIT License (MIT). Please see LICENCE file for more information.
