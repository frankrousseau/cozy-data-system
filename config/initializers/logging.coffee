module.exports = (compound) ->
    console.log = (text) ->
        if process.env.NODE_ENV is "production"
            compound.logger.write text

    console.info = (text) ->
        if process.env.NODE_ENV is "production"
            compound.logger.write text

    console.err = (text) ->
        if process.env.NODE_ENV is "production"
            compound.logger.write text

    console.warn = (text) ->
        if process.env.NODE_ENV is "production"
            compound.logger.write text
