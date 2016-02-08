hubot-skype-web
===============

A [Skype](http://www.skype.com/) adapter for [Hubot](https://hubot.github.com/) that connects via Skype web.

[![Version](https://img.shields.io/npm/v/hubot-skype-web.svg)](https://github.com/sdimkov/hubot-skype-web/releases)
[![License](https://img.shields.io/npm/l/express.svg)](https://github.com/sdimkov/hubot-skype-web/blob/master/LICENSE)
[![Downloads](https://img.shields.io/npm/dm/hubot-skype-web.svg)](https://www.npmjs.com/package/hubot-skype-web)

This adapter allows integrating your Hubot with Skype.

Available functionality:
* Sending / Receiving messages in personal chats with contacts
* Sending / Receiving messages in group chats with anyone in the group (non-contacts included)

What's missing:
* Sending / Accepting / Rejecting contact requests
* Sending / Receiving of files
* Recognizing contact presense (appearing online ; going offline..etc)

Also note that this adapter can not connect to the old P2P group chats. That's a general limitation of Skype's web offerings as the old P2P groups don't go through Skype's servers. Read more about cloud-based and P2P-based Skype groups [here](https://support.skype.com/en/faq/FA12381/what-is-the-cloud)

Getting started
---------------

1. Install [PhantomJS](http://phantomjs.org/). This adapter depends on [phantom](https://github.com/amir20/phantomjs-node) which expects you to manually install the PhantomJS binary and expose it in PATH
3. Export necessary environment variables.
4. Add `hubot-skype-web` as dependency in your package.json: `npm install hubot-skype-web --save`
5. Start your hubot with the Skype Web adapter: `hubot --adapter skype-web`

Configuration
-------------

This adapter can only be configured via Environment variables.

Mandatory Environment variables:
* `HUBOT_SKYPE_USERNAME` _String_ - hubot's skype account username
* `HUBOT_SKYPE_PASSWORD` _String_ - hubot's skype account password in plain text

Optional Environment variables:
* `HUBOT_SKYPE_RECONNECT` _Integer, default: 240_ - The duration between reconnects in minutes. Minimum value is 20. Reconnect does not disturb hubot's uptime.
* `HUBOT_LOG_LEVEL` _String [debug|info|notice|warning|error|critical|alert|emergency], default: info_ - Set the log level of Hubot. The SkypeWeb adapter can output extensive debug messages.
* `HUBOT_SKYPE_MAX_MESSAGE_LENGTH` _Integer, default 1500_ - The maximum length of the message, longer messages are splitted

Contributing
------------

Patches are welcome. Browse the [documentation](https://cdn.rawgit.com/sdimkov/hubot-skype-web/1fe385848dff0cc01290825cd7a2abe2fa4d3f5a/doc/index.html) to get started.

Troubleshooting
---------------

Please fill in issues to this Github project istead of emailing me directly. Keeping the communication here saves me from answering multiple emails for the same things.

You may have troubles running this under Linux with PhantomJS 1.9. You should try using 2.0. At the time of writting this there is still no official build. You can find my build [here](https://groups.google.com/forum/#!searchin/phantomjs/dimkov/phantomjs/CAasXq1Yzz0/fyjIm58cXk8J).

License
-------

The MIT License (MIT). Please see LICENSE file for more information.
