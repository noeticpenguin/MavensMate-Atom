{$, $$$, ScrollView, View} = require 'atom'
Convert = null
{Subscriber,Emitter} = require 'emissary'
emitter   = require('./mavensmate-emitter').pubsub
util      = require './mavensmate-util'

class MavensMatePanelViewItem extends View

  constructor: (params, message) ->
    super
    promiseId = params.promiseId
    @item.attr 'id', promiseId
    console.log '>>>>>'
    console.log message
    @detail.html message

    @commandA.attr 'href', '#command-'+promiseId
    @commandA.attr 'id', 'commandA-'+promiseId
    @commandPane.attr 'id', 'command-'+promiseId
    @messageA.attr 'href', '#message-'+promiseId
    @messageA.attr 'id', 'messageA-'+promiseId
    @messagePane.attr 'id', 'message-'+promiseId
    @stackTraceA.attr 'href', '#stackTrace-'+promiseId
    @stackTraceA.attr 'id', 'stackTraceA-'+promiseId
    @stackTracePane.attr 'id', 'stackTrace-'+promiseId

    @pillBar.find('a').click (e) ->
      console.log 'anchor clickeD!'
      e.preventDefault()
      $(this).tab "show"
      return

  # Internal: Initialize mavensmate output view DOM contents.
  @content: ->
    @div class: 'panel-item',  =>
      @div outlet: 'item', =>
        @div class: 'container-fluid', =>
          @div class: 'row', =>
            @div class: 'col-md-1', =>
              @div class: 'progress progress-striped active', =>
                @div class: 'progress-bar', role: 'progressbar', 'aria-valuenow': '100', 'aria-valuemax': '100', style: 'width:100%', =>
                  @span class: 'sr-only'
            # @div class: 'col-md-1', =>
            #   @progress class: 'pending', max: '100', value: '100', =>
            #     @div class: 'progress-bar', =>
            #       @span style: 'width:100%'
            @div class: 'col-md-11', =>
              @ul class: 'nav nav-pills', outlet: 'pillBar', =>
                @li class: 'active', =>
                  @a outlet: 'commandA', 'Command'
                @li class: '', =>
                  @a outlet: 'messageA', 'Result'
                @li class: '', =>
                  @a outlet: 'stackTraceA', 'Stack Trace'
              @div class: 'tab-content', =>
                @div class: 'tab-pane active', outlet: 'commandPane', =>
                  @div outlet: 'detail'
                @div class: 'tab-pane', outlet: 'messagePane', =>
                  @div 'some stuff in messages'
                @div class: 'tab-pane', outlet: 'stackTracePane', =>
                  @div =>
                    @pre 'foo bar bat'

  initialize: ->

  updateStatus: (status) ->


# The status panel that shows the result of command execution, etc.
class MavensMatePanelView extends View
  Subscriber.includeInto this

  # Internal: Initialize mavensmate output view DOM contents.
  @content: ->
    @div tabIndex: -1, class: 'mavensmate mavensmate-output tool-panel panel-bottom native-key-bindings', =>
      @h3 outlet: 'myHeader'
      @div class: 'block padded mavensmate-panel', =>
        @div class: 'message', outlet: 'myOutput'

  # Internal: Initialize the mavensmate output view and event handlers.
  initialize: ->
    @myHeader.html('MavensMate for Atom.io')
    #@myOutput.html(@output).css('font-size', "#{atom.config.getInt('editor.fontSize')}px")

    me = @
    emitter.on 'mavensmatePanelNotifyStart', (params, promiseId) ->
      command = util.getCommandName params
      if command not in util.panelExemptCommands()
        params.promiseId = promiseId
        me.update command, params
      return

    emitter.on 'mavensmatePanelNotifyFinish', (params, result, promiseId) ->
      console.log 'finish!'
      console.log params
      console.log result
      command = util.getCommandName(params)
      if command not in util.panelExemptCommands()
        panelOutput = me.getPanelOutput command, params, result

        console.log 'panel output ---->'
        console.log panelOutput

        # update progress bar depending on outcome of command
        #
        # TODO: not all commands will return success true/false unfortunately (tooling api compiles, for example)
        panelItemProgressBar = me.myOutput.find('div#'+promiseId+' div.progress')
        panelItemProgressBar.attr 'class', 'progress'

        # grab progress bar
        panelItemProgressBarDiv = me.myOutput.find('div#'+promiseId+' div.progress > div')

        # update status indicator
        panelItemProgressBarDiv.attr 'class', 'progress-bar progress-bar-'+panelOutput.indicator

        # put message in panel
        messagePane = me.myOutput.find('div#message-' + promiseId)
        console.log messagePane
        messagePane.html panelOutput.message

        # add stackTrace
        stackTracePane = me.myOutput.find('div#stackTrace-' + promiseId + " div pre")
        stackTracePane.html panelOutput.stackTrace

        # show message panel
        messageAnchor = me.myOutput.find('a#messageA-' + promiseId)
        messageAnchor.click()
      return

  # transforms the JSON returned by the cli into an object with properties that conform to the panel
  #
  # output =
  #   message: '(Line 17) Unexpected token, yada yada yada'
  #   indicator: 'success' #warning, danger, etc. (bootstrap label class names)
  #   stackTrace: 'foo bar bat'
  #   isException: true
  #
  getPanelOutput: (command, params, result) ->
    console.log '~~~~~~~~~~~'
    console.log command
    console.log params
    console.log result
    obj = null
    if params.args? and params.args.ui
      console.log 'cool!'
      obj = @getUiCommandOutput command, params, result
    else
      switch command
        when 'compile'
          obj = @getCompileCommandOutput command, params, result
        when 'run_all_tests'
          obj = @getRunAllTestsCommandOutput command, params, result
        else
          obj = @getGenericOutput command, params, result

    return obj

  getUiCommandOutput: (command, params, result) ->
    console.log 'parsing ui'
    if result.success
      obj =
        message: 'UI generated successfully'
        indicator: 'success'
      return obj
    else
      return @getErrorOutput command, params, result

  getErrorOutput: (command, params, result) ->
    output =
      message: result.body
      indicator: 'danger'
      stackTrace: result.stackTrace
      isException: result.stackTrace?

  getGenericOutput: (command, params, result) ->
    if result.body? and result.success?
      output =
        message: result.body
        indicator: if result.success then 'success' else 'danger'
        stackTrace: result.stackTrace
        isException: result.stackTrace?
    else
      output =
        message: 'No result message could be determined'
        indicator: 'warning'
        stackTrace: result.stackTrace
        isException: result.stackTrace?

  getCompileCommandOutput: (command, params, result) ->
    obj =
      message: null
      indicator: null
      stackTrace: null
      isException: false

    if result.State? # tooling
      if result.state is 'Error' and result.ErrorMsg?
        obj.message = result.ErrorMsg
        obj.success = false
      else if result.State is 'Failed' and result.CompilerErrors?
        if Object.prototype.toString.call result.CompilerErrors is '[object String]'
          result.CompilerErrors = JSON.parse result.CompilerErrors

        errors = result.CompilerErrors

        message = ''
        errorLines = []
        for error in errors
          if error.line?
            message += '(Line '+error.line+') '
            errorLines.push error.line
          message += error.problem
        obj.message = message
        obj.indicator = 'danger'

        console.log 'NEED TO EMIT TO BUFFER MANAGER HERE'
        #console.log params.args.editor
        #console.log params.args.editor.gutter
        emitter.emit 'mavensmateCompileErrorBufferNotify', command, params, result, errorLines

      else if result.State is 'Completed' and not result.ErrorMsg
        obj.indicator = 'success'
        obj.message = 'Success'
        emitter.emit 'mavensmateCompileSuccessBufferNotify', params
      else
        #pass
    else if result.actions?
      # need to diff
      obj.message = result.body
      obj.indicator = 'warning'
    else # metadata api
      #todo

    return obj

  getRunAllTestsCommandOutput: (command, params, result) ->
    obj =
      message: null
      indicator: null
      stackTrace: ""
      isException: false

    passCounter = 0
    failedCounter = 0

    for apexClass in result
      for test in apexClass.detailed_results
        if test.Outcome == "Fail"
          failedCounter++
          obj.message = "#{failedCounter} failed test method"
          obj.message += "s" if failedCounter > 1
          obj.stackTrace += "\n#{test.ApexClass.Name}.#{test.MethodName}:\n#{test.StackTrace}\n"
          obj.indicator = 'danger'
          obj.isException = true
        else
          passCounter++


    if failedCounter == 0
      obj.message = "Run all tests complete. #{passCounter} test" + (if passCounter > 1 then "s " else " ") + "passed."
      obj.indicator = 'success'

    return obj



  # Internal: Update the mavensmate output view contents.
  #
  # output - A string of the test runner results.
  #
  # Returns nothing.
  update: (command, params) ->
    # Convert ?= require 'ansi-to-html'
    # convert = new Convert
    # @output = convert.toHtml(output)
    # @myTableBody.append("<pre>#{@output.trim()}</pre>")
    console.log params
    isUi = util.isUiCommand params
    message = util.panelCommandMessage params, command, isUi
    console.log params
    panelItem = new MavensMatePanelViewItem(params, message)
    @myOutput.prepend panelItem
    # @myOutput.prepend '<div class="panel-item"><div>'+operation+'</div></div>'

  # Internal: Detach and destroy the mavensmate output view.
  #
  # Returns nothing.
  destroy: ->
    @detach()

  # Internal: Toggle the visibilty of the mavensmate output view.
  #
  # Returns nothing.
  toggle: ->
    if @hasParent()
      @detach()
    else
      atom.workspaceView.prependToBottom(this) unless @hasParent() #todo: attach to specific workspace view

panel = new MavensMatePanelView()
exports.panel = panel
