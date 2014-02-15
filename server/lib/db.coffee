fs = require 'fs'
logger = require('printit')
    date: false
    prefix: 'lib:db'
S = require 'string'
Client = require("request-json").JsonClient
couchUrl = "http://localhost:5984/"
couchClient = new Client couchUrl
initTokens = require('../lib/token').init
request = require('../lib/request')

logger = require('printit')
    date: true
    prefix: 'lib/db'

module.exports = (callback) ->
    feed = require '../lib/feed'
    db = require('../helpers/db_connect_helper').db_connect()

    ### Helpers ###

    initLoginCouch = ->
        data = fs.readFileSync '/etc/cozy/couchdb.login'
        lines = S(data.toString('utf8')).lines()
        return lines

    # Add admin to cozy database
    # Result : Unauthorized applications cannot read on cozy
    addCozyAdmin = (callback) ->
        loginCouch = initLoginCouch()
        data =
            "admins":
                "names":[loginCouch[0]]
                "roles":[]
            "readers":
                "names":[loginCouch[0], 'proxy']
                "roles":[]
        couchClient.setBasicAuth(loginCouch[0],loginCouch[1])
        couchClient.put 'cozy/_security', data, (err, res, body)->
            callback err

    addCozyUser = (callback) ->
        loginCouch = initLoginCouch()
        data =
            "_id": "org.couchdb.user:proxy",
            "name": "proxy",
            "type": "user",
            "roles": [],
            "password": process.env.TOKEN
        couchClient.setBasicAuth(loginCouch[0],loginCouch[1])
        couchClient.post '_users', data, (err, res, body)->
            callback err


    ### Logger ###

    logFound = ->
        logger.info "Database #{db.name} on #{db.connection.host}" +
            ":#{db.connection.port} found."
        feed_start()
        request_create()

    logError = (err) ->
        logger.info "Error on database creation : "
        logger.info err

    logCreated = ->
        logger.info "Database #{db.name} on" +
            " #{db.connection.host}:#{db.connection.port} created."
        feed_start()
        request_create()


    ### Check existence of cozy database or create it ###
    db_ensure = (callback) ->
        db.exists (err, exists) ->
            if err
                logger.write "Error:", err
            else if exists
                if process.env.NODE_ENV is 'production'
                    loginCouch = initLoginCouch()
                    couchClient.setBasicAuth(loginCouch[0],loginCouch[1])
                    couchClient.get 'cozy/_security', (err, res, body)=>
                        if not body.admins? or
                                body.admins.names[0] isnt loginCouch[0] or
                                body.readers?.names[0] isnt 'proxy'
                            addCozyUser (err) ->
                                if err
                                    logger.write "Error on database" +
                                    " Add user : #{err}"
                                    callback()
                                else
                                    addCozyAdmin (err) =>
                                        if err
                                            logger.write "Error on database" +
                                            " Add admin : #{err}"
                                            callback()
                                        else
                                            logFound()
                                            callback()
                        else
                            logFound()
                            callback()
                else
                    logFound()
                    callback()
            else
                db_create(callback)

    db_create = (callback)->
        logger.info "Database #{db.name} on" +
                " #{db.connection.host}:#{db.connection.port} doesn't exist."
        db.create (err) ->
            if err
                logError(err)
                db_create(callback)
            else if (process.env.NODE_ENV is 'production')
                addCozyUser (err) ->
                    if err
                        logger.info "Error on database" +
                        " Add user : #{err}"
                        callback()
                    else
                        addCozyAdmin (err) =>
                            if err
                                logError(err)
                                callback()
                            else
                                logCreated()
                                callback()
            else
                logCreated()
                callback()

    # this request is used to retrieved all the doctypes in the DS
    request_create = ->
        db.get '_design/doctypes', (err, doc) =>
            if err and err.error is "not_found"
                db.save '_design/doctypes',
                    all:
                        map: """
                        function(doc) {
                            if(doc.docType) {
                                return emit(doc.docType, null);
                            }
                        }
                        """
                        # use to make a "distinct"
                        reduce: """
                        function(key, values) {
                            return true;
                        }
                        """

        db.get '_design/device', (err, doc) =>
            if err and err.error is "not_found"
                db.save '_design/device',
                    all:
                        map: """
                        function(doc) {
                            if(doc.docType && doc.docType.toLowerCase === "device") {
                                return emit(doc._id, doc);
                            }
                        }
                        """
                    byLogin:
                        map: """
                        function (doc) {
                            if(doc.docType && doc.docType.toLowerCase() === "device") {
                                return emit(doc.login, doc)
                            }
                        }
                        """

        db.get '_design/tags', (err, doc) =>
            if err and err.error is "not_found"

                db.save '_design/tags',
                    all:
                        map: """
                        function (doc) {
                        var _ref;
                        return (_ref = doc.tags) != null ? typeof _ref.forEach === "function" ? _ref.forEach(function(tag) {
                           return emit(tag, null);
                            }) : void 0 : void 0;
                        }
                        """
                        # use to make a "distinct"
                        reduce: """
                        function(key, values) {
                            return true;
                        }
                        """

    feed_start = -> feed.startListening db

    db_ensure () ->
        initTokens (tokens, permissions) =>
            request.init (err) =>
                callback() if callback?

