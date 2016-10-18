class PageHelper


  constructor: (@page, @options = {}) ->
    @options.waitMax   ||= 30  # seconds
    @options.waitStep  ||= 50  # milliseconds
    @options.waitAfter ||= 50  # milliseconds


  wait: (selector, callback, start) ->
    self = @
    start ||= (new Date).getTime()
    self.page.evaluate ((selector) ->
      obj = document.querySelector selector
      return obj isnt null and
          obj.clientWidth   isnt 0 and obj.clientHeight     isnt 0 and
          obj.style.opacity isnt 0 and obj.style.visibility isnt 'hidden'
    ), (success) ->
      if success
        setTimeout callback, self.options.waitAfter
      else
        now = (new Date).getTime()
        if now - start < self.options.waitMax * 1000
          setTimeout (->
            self.wait selector, callback, start
          ), self.options.waitStep
        else
          throw new Error "Timeout after #{self.options.waitMax} " +
                               "sec while waiting for '#{selector}'"
    , selector


  fillForm: (fields) ->
    @page.evaluate ((fields) ->
      for selector, value of fields
        document.querySelector(selector).value = value
      document.forms[0].submit()
    ), (->), fields


module.exports = PageHelper