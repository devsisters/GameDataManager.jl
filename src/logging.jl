
function init_logger()
    global LOGGING = open(joinpath(GAMEENV["cache"], "log.txt"), "w+")
    logger = SimpleLogger(LOGGING)
    global_logger(logger)
end