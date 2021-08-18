package program;

import program.logger.WindowHandler;

import javax.swing.*;
import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.Logger;

public class Main {
    public static boolean argNoLog = false;

    public static PermaFile propertyFile;

    private WindowHandler handler = null;
    private Logger logger = null;

    public static void main(String[] args) throws Exception {

        //Reformat javaagent arguments to normal arguments
        if(args.length>0 && args[0].startsWith("agentArgs")){
            args = (args[0].split("="))[1].split(",");
        }
        for (String s: args){
            if (s.equals("noLog")) argNoLog = true;
        }

        WindowHandler h = WindowHandler.getInstance();
        LogRecord r = new LogRecord(Level.INFO, "Synhat Starting with Args ="+ String.join(" ",args));
        h.publish(r);

        try {
            propertyFile = new PermaFile(FileConsts.permanentStorageFile);
        } catch (IOException e) {
            h.publish(new LogRecord(Level.SEVERE, e.getMessage()));
        }

        if (GithubDownloader.isOutdated()) {
            try {
                String vname = GithubDownloader.downloadLatestZip();
                GithubDownloader.unzip();
            } catch (Exception e) {}
        }

        SwingUtilities.invokeLater(new Runnable() {
            public void run() {
                Window.msgBox("Synhat "+propertyFile.content.get(PermaFile.installedPackName)+" sucesfully installed");
            }
        });
    }
}

