phantom = require 'phantom'
request = require 'request'
util    = require 'util'

{Adapter, TextMessage, User} = require 'hubot'


class SkypeWeb extends Adapter


  constructor: (@robot) ->
    super @robot
    url      = "https://client-s.gateway.messenger.live.com"
    @urlPoll = "#{url}/v1/users/ME/endpoints/SELF/subscriptions/0/poll"
    @urlSend = (user) -> "#{url}/v1/users/ME/conversations/#{user}/messages"
    @headers = {}
    @bodySend = messagetype: 'RichText', contenttype: 'text', content: ''

    # Configuration
    @skypeUsername = process.env.HUBOT_SKYPE_USERNAME
    @skypePassword = process.env.HUBOT_SKYPE_PASSWORD
    @reconnectInterval = false
    if process.env.HUBOT_SKYPE_RECONNECT
      @reconnectInterval = parseInt process.env.HUBOT_SKYPE_RECONNECT
      if @reconnectInterval < 20
        @robot.logger.warning 'HUBOT_SKYPE_RECONNECT is the adapter ' +
                  'reconnect interval in minutes! (optional parameter)'
        throw new Error 'Minimum reconnect interval is 20 minutes!'
      @reconnectInterval *= 60 * 1000  # convert minutes to milliseconds


  run: ->
    self = @
    self.login
      success: ->
        self.emit 'connected'
        self.pollRequest()
        if @reconnectInterval
          setInterval (-> self.login()), @reconnectInterval
          self.robot.logger.info "SkypeWeb adapter configured to reconnect" +
                                 "every #{@reconnectInterval} minutes"
      error: ->
        throw new Error 'SkypeWeb adapter failure in initial login!'


  send: (envelope, strings...) ->
    @sendInQueue envelope.room, msg for msg in strings


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


  login: (options = {}) ->
    self = @
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
            self.robot.logger.debug request.url

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
            ), (->), self.skypeUsername, self.skypePassword
          ), 5000  # after 5 secs

    ), dnodeOpts: weak: false  # Needed for PhantomJS on Windows


  copyHeaders: (request) ->
    @headers = {}
    for header in request.headers
      @headers[header.name] = header.value
    # Clear Content-Length as we won't bother setting correct value
    delete @headers['Content-Length']
    @headers['Host'] = 'client-s.gateway.messenger.live.com'
    @headers['Connection'] = 'keep-alive'
    @headers['Accept-Encoding'] = 'gzip, deflate'


  eventsCache: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
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
      return if userID is @skypeUsername
      user = @robot.brain.userForId userID
      user.room = msg.resource.conversationLink.split('/conversations/')[1]
      # Let robot know messages in personal chats are directed at him
      if user.room.indexOf('19:') isnt 0
        unless user.shell? and user.shell[user.room]
          @robot.logger.debug 'prefix personal message'
          msg.resource.content = @robot.name + ': ' + msg.resource.content
      # Provide the messages to the robot
      @receive new TextMessage user, msg.resource.content, msg.resource.id


  sendQueues: {}
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


  sendRequest: (user, msg) ->
    self = @
    now = new Date().getTime()
    @headers.ContextId        = now
    @bodySend.clientmessageid = now
    @bodySend.content = msg
    request.post(
      url: @urlSend(user),
      headers: @headers,
      body: @bodySend,
      gzip: true, json: true,
      (error, response, body) ->
        unless response.statusCode in [200, 201]
          self.robot.logger.error "send request returned status " +
              "#{response.statusCode}. user='#{user}' msg='#{msg}'"
        if error
          self.robot.logger.error "send request failed: " + error
        self.sendQueues[user].shift()
        # process remaining messages in queue
        if self.sendQueues[user].length isnt 0
          self.sendRequest user, self.sendQueues[user][0]
    )


  pollRequest: ->
    self = @
    @headers.ContextId = new Date().getTime()
    request.post(
      url: @urlPoll,
      headers: @headers,
      gzip: true,
      (error, response, body) ->
        if error
          self.robot.logger.error error
        else
          try
            if body.trim()
              body = JSON.parse body
              self.onEventMessage msg for msg in body.eventMessages
          catch err
            self.robot.logger.error 'Failure in parsing poll results: ' + err
        self.pollRequest()
    )


exports.use = (robot) ->
  new SkypeWeb robot
