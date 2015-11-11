{Emitter} = require 'atom'
ColorExpression = require './color-expression'
vm = require 'vm'

module.exports =
class ExpressionsRegistry
  @deserialize: (serializedData, expressionsType) ->
    registry = new ExpressionsRegistry(expressionsType)

    for name, data of serializedData.expressions
      handle = vm.runInNewContext(data.handle.replace('function', "handle = function"))
      registry.createExpression(name, data.regexpString, handle)

    registry.regexpString = serializedData.regexpString

    registry

  # The {Object} where color expression handlers are stored
  constructor: (@expressionsType) ->
    @colorExpressions = {}
    @emitter = new Emitter

  dispose: ->
    @emitter.dispose()

  onDidAddExpression: (callback) ->
    @emitter.on 'did-add-expression', callback

  onDidRemoveExpression: (callback) ->
    @emitter.on 'did-remove-expression', callback

  onDidUpdateExpressions: (callback) ->
    @emitter.on 'did-update-expressions', callback

  getExpressions: ->
    (e for k,e of @colorExpressions).sort((a,b) -> b.priority - a.priority)

  getExpression: (name) -> @colorExpressions[name]

  getRegExp: ->
    @regexpString ?= @getExpressions().map((e) -> "(#{e.regexpString})").join('|')

  createExpression: (name, regexpString, priority=0, handle) ->
    [priority, handle] = [0, priority] if typeof priority is 'function'
    newExpression = new @expressionsType({name, regexpString, handle})
    newExpression.priority = priority
    @addExpression newExpression

  addExpression: (expression, batch=false) ->
    delete @regexpString
    @colorExpressions[expression.name] = expression

    unless batch
      @emitter.emit 'did-add-expression', {name: expression.name, registry: this}
      @emitter.emit 'did-update-expressions', {name: expression.name, registry: this}
    expression

  createExpressions: (expressions) ->
    @addExpressions expressions.map (e) =>
      {name, regexpString, handle, priority} = e
      priority ?= 0
      expression = new @expressionsType({name, regexpString, handle})
      expression.priority = priority
      expression

  addExpressions: (expressions) ->
    for expression in expressions
      @addExpression(expression, true)
      @emitter.emit 'did-add-expression', {name: expression.name, registry: this}
    @emitter.emit 'did-update-expressions', {registry: this}

  removeExpression: (name) ->
    delete @regexpString
    delete @colorExpressions[name]
    @emitter.emit 'did-remove-expression', {name, registry: this}
    @emitter.emit 'did-update-expressions', {name, registry: this}

  serialize: ->
    out =
      regexpString: @getRegExp()
      expressions: {}

    for key, expression of @colorExpressions
      out.expressions[key] =
        name: expression.name
        regexpString: expression.regexpString
        handle: expression.handle?.toString()

    out
