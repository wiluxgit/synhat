package program.logger;

import java.util.logging.Logger;

public class CustomHandlerDemo {
    private WindowHandler handler = null;

    private Logger logger = null;

    public CustomHandlerDemo() {
        handler = WindowHandler.getInstance();
        //obtaining a logger instance and setting the handler
        logger = Logger.getLogger("sam.logging.handler");
        logger.addHandler(handler);
    }

    /**
     * This method publishes the log message
     */
    public void logMessage() {
        logger.info("Hello from WindowHandler...");
    }
    public void logMessage(String s){
        logger.info(s);
    }
}
