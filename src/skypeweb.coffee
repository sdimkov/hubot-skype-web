phantom = require 'phantom'
request = require 'request'
util    = require 'util'
escape  = require 'escape-html'
fs      = require 'fs'

{Adapter, TextMessage, User} = require 'hubot'


class SkypeWebAdapter extends Adapter


  # @param robot [Robot] the instance of hubot that uses the adapter
  constructor: (@robot) ->
    super @robot

    url       = "https://client-s.gateway.messenger.live.com"
    @pollUrl  = "#{url}/v1/users/ME/endpoints/SELF/subscriptions/0/poll"
    @sendUrl  = (user) -> "#{url}/v1/users/ME/conversations/#{user}/messages"
    @sendBody = messagetype: 'RichText', contenttype: 'text', content: ''
    @sendQueues = {}
    @headers    = false
    @eventsCache = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    @respondPattern = @robot.respondPattern /.*/

    # Read and validate username
    @username = process.env.HUBOT_SKYPE_USERNAME
    if not @username or @username.length < 2
      throw new Error 'Provide a valid username in HUBOT_SKYPE_USERNAME!'
    # Read and validate password
    @password = process.env.HUBOT_SKYPE_PASSWORD
    if not @username or @username.length < 2
      throw new Error 'Provide a valid password in HUBOT_SKYPE_PASSWORD!'
    # Read and validate reconnect interval
    @reconnectInterval = 240
    if process.env.HUBOT_SKYPE_RECONNECT
      @reconnectInterval = parseInt process.env.HUBOT_SKYPE_RECONNECT
      if @reconnectInterval < 20
        @robot.logger.warning 'HUBOT_SKYPE_RECONNECT is the adapter ' +
                  'reconnect interval in minutes! (optional parameter)'
        throw new Error 'Minimum reconnect interval is 20 minutes!'


  # Starts the adapter
  #
  run: ->
    self = @
    success = ->
      self.emit 'connected'
      self.pollRequest()
      if self.reconnectInterval
        setInterval (-> self.login()), self.reconnectInterval * 60 * 1000
        self.robot.logger.info "SkypeWeb adapter configured to reconnect " +
                               "every #{self.reconnectInterval} minutes"
    error = ->
      throw new Error 'SkypeWeb adapter failure in initial login!'

    backup = false
    try backup = JSON.parse fs.readFileSync 'hubot-skype-web.backup', 'utf8'

    if backup and new Date(backup.expire) > new Date()
      self.robot.logger.info 'Skype headers restored from backup.'
      self.headers = backup.headers
      success()
      setTimeout (-> self.login()), 5000
    else
      @login success: success, error: error


  # Entry point for messages from hubot
  #
  send: (envelope, strings...) ->
    @sendInQueue envelope.room, msg for msg in strings


  # Replies back to a specific user.
  #
  # @note it prefixes messages only in group chats
  #
  reply: (envelope, strings...) ->
    # Only prefix replies in group chats
    if envelope.user.room.indexOf('19:') is 0
      @robot.logger.debug 'reply: adding receiver prefix to all strings'
      strings = strings.map (s) -> "#{envelope.user.nickname ||
                                      envelope.user.name}: #{s}"
    else
      @robot.logger.debug 'reply: replying in personal ' +
                          'chat ' + envelope.user.room
    @send envelope, strings...


  # @private
  # Login to Skype web client and retrieve a sample poll request.
  #
  # @note Uses PhantomJS to render the web page and monitor network traffic
  #
  # @option options [Function] success executed if the correct requests are found
  # @option options [Function] error executed if the time exceeds the limit
  #
  login: (options = {}) ->
    self = @
    phantomOptions = {}
    if process.platform.indexOf('win') isnt -1
      # Disable dnode with weak on Windows hosts
      phantomOptions.dnodeOpts = weak: false
    phantom.create ((ph) ->
      ph.createPage (page) ->
        # Execute fail condition if login time limit expires
        errorTimer = setTimeout (->
          self.robot.logger.error 'SkypeWeb adapter failed to login!'
          page.close()
          ph.exit 0
          options?.error?()
        ), 50000  # after 50 secs
        # Monitor outgoing requests until proper poll request appears
        requestsCount = 0
        success       = false
        page.set 'onResourceRequested', (request) ->
          if request.url.indexOf 'poll' > 0 and request.method is 'POST'
            for header in request.headers
              if header.name is 'RegistrationToken'
                return if requestsCount++ < 5 or success
                page.close()
                ph.exit 0
                # Clear timer for error condition
                clearTimeout errorTimer
                self.robot.logger.info 'SkypeWeb adapter logged in successfully!'
                self.robot.logger.debug 'Captured poll request: \n' +
                                        util.inspect request
                self.copyHeaders request
                success = true
                options?.success?()
          else
            self.robot.logger.debug 'Skype during login: ' + request.url
        # Use sane user-agent
        page.set 'settings.userAgent',
          'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36'
        # Login to skype web
        page.open 'https://web.skype.com', (status) ->
          setTimeout (->
            page.evaluate ((username, password) ->
              document.getElementById('username').value = username
              document.getElementById('password').value = password
              document.getElementById('signIn').click()
            ), (->), self.username, self.password
          ), 5000  # after 5 secs

    ), phantomOptions


  # @private
  # Stores all request headers of the intercepted request for later use.
  #
  # @note Most importantly it optains the RegistrationToken which is used
  #   to authenticate the requests for receiving or sending messages
  #
  # @param request [Request] the poll request made from skype web client
  #
  copyHeaders: (request) ->
    @headers = {}
    for header in request.headers
      @headers[header.name] = header.value
    # Clear Content-Length as we won't bother setting correct value
    delete @headers['Content-Length']
    @headers['Host'] = 'client-s.gateway.messenger.live.com'
    @headers['Connection'] = 'keep-alive'
    @headers['Accept-Encoding'] = 'gzip, deflate'
    self = @
    backup = JSON.stringify
      expire: new Date(new Date().getTime() + self.reconnectInterval * 60 * 1000)
      headers: self.headers

    fs.writeFile 'hubot-skype-web.backup', backup, (err) ->
      if err
        self.robot.logger.error 'IO error while storing ' +
                             'Skype headers to disc:' + err
      else
        self.robot.logger.debug 'Skype headers stored to disc successfully'


  # @private
  # Handles all Skype events coming from the server
  #
  # @param msg [EventMessage] the event object
  #
  onEventMessage: (msg) ->
    if (msg.resourceType is 'NewMessage' and
        msg.resource?.messagetype in ['Text', 'RichText'])
      # Make sure we don't process same pessage once
      # (Happens when you switch RegistrationToken-s)
      return if msg.resource.id in @eventsCache
      @eventsCache.shift()
      @eventsCache.push msg.resource.id
      userID = msg.resource.from.split('/contacts/')[1].replace '8:', ''
      # Ignore messages sent by the robot
      return if userID is @username
      user = @robot.brain.userForId userID
      user.room = msg.resource.conversationLink.split('/conversations/')[1]
      # Let robot know messages in personal chats are directed at him
      if user.room.indexOf('19:') isnt 0
        unless user.shell? and user.shell[user.room]
          # Only prefix messages that aren't already prefixed by sender
          unless @respondPattern.test msg.resource.content
            @robot.logger.debug 'Prefix personal message from ' + user.name
            msg.resource.content = @robot.name + ': ' + msg.resource.content
      # Provide the messages to the robot
      @receive new TextMessage user, msg.resource.content, msg.resource.id


  # @private
  # Store skype message to be send in queues
  #
  # @note This prevents this prevents newer messages to be received prior
  #   to older ones due to the async nature of the requests being made
  #
  # @param user [String] the recipient of the message
  # @param msg [String] the contents of the message to be send
  #
  sendInQueue: (user, msg) ->
    @sendQueues[user] ||= []
    queue = @sendQueues[user]
    # Split messages that can't be sent at once
    if msg.length > 1500
      @robot.logger.warning 'Message too long for sending! Splitting...'
      index = msg.substring(0, 1500).lastIndexOf("\n")
      index = 1500 if index is -1
      @sendInQueue user, msg.substring 0, index
      @sendInQueue user, msg.substring index + 1
      return
    queue.push msg
    len = queue.length
    return @sendRequest user, msg if len is 1
    # Optimize queue by truncating next messages
    if len > 2 and queue[len-1].length + queue[len-2].length < 1500
      queue[len-2] += "\n" + queue.pop()


  # @private
  # Sends POST request to skype containing new message to given user
  #
  # @note it recursively calls itself until queues are empty
  #
  # @param user [String] the recipient of the message
  # @param msg [String] the contents of the message to be send
  #
  sendRequest: (user, msg) ->
    self = @
    now = new Date().getTime()
    @headers.ContextId        = now
    @sendBody.clientmessageid = now
    @sendBody.content = escape msg
    request.post(
      url: @sendUrl(user),
      headers: @headers,
      body: @sendBody,
      gzip: true, json: true,
      (error, response, body) ->
        unless response.statusCode in [200, 201]
          self.robot.logger.error "Send request returned status " +
              "#{response.statusCode}. user='#{user}' msg='#{msg}'"
        if error
          self.robot.logger.error "Send request failed: " + error
        self.sendQueues[user].shift()
        # process remaining messages in queue
        if self.sendQueues[user].length isnt 0
          self.sendRequest user, self.sendQueues[user][0]
    )


  # @private
  # Polls the server for new events.
  #
  # @note it recursively calls itself
  #
  pollRequest: ->
    self = @
    @headers.ContextId = new Date().getTime()
    request.post(
      url: @pollUrl,
      headers: @headers,
      gzip: true,
      (error, response, body) ->
        if error
          self.robot.logger.error 'Poll request failed: ' + error
        else
          try
            if body.trim()
              body = JSON.parse body

              if 0 == Object.keys(body).length
                throw new Error "empty response"
              else if body.errorCode?
                throw new Error body.message

              self.onEventMessage msg for msg in body.eventMessages
          catch err
            self.robot.logger.error 'Parsing poll results failed: ' + err
        self.pollRequest()
    )


exports.use = (robot) ->
  new SkypeWebAdapter robot
