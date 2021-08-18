package program;

import program.logger.WindowHandler;

import javax.swing.*;
import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.Logger;

public class Main {
    public static boolean argNoLog = false;
    public static boolean argPromptDownload = false;

    public static PermaFile propertyFile;

    public static WindowHandler windowHandler = null;
    private Logger logger = null;

    public static void main(String[] args) {

        //Reformat javaagent arguments to normal arguments
        if(args.length>0 && args[0].startsWith("agentArgs")){
            args = (args[0].split("="))[1].split(",");
        }
        for (String s: args){
            if (s.equals("noLog")) argNoLog = true;
            if (s.equals("promptDownload")) argPromptDownload = true;
        }

        windowHandler = WindowHandler.getInstance();
        LogRecord r = new LogRecord(Level.INFO, "Synhat Starting with Args ="+ String.join(" ",args));
        windowHandler.publish(r);

        try {
            propertyFile = new PermaFile(FileConsts.permanentStorageFile);
        } catch (IOException e) {
            windowHandler.publish(new LogRecord(Level.SEVERE, e.getMessage()));
        }

        try {
            if (GithubDownloader.isOutdated()) {
                windowHandler.publishInfo("A new version is available, downloading automatically");
                String versionName = GithubDownloader.downloadLatestZip();
                GithubDownloader.unzip();
                windowHandler.publishInfo(versionName+" Downloaded Successfully");
            }
        } catch (IOException e) {
            windowHandler.publish(new LogRecord(Level.WARNING, "CAN NOT ACCESS SYNHAT REPO\n"+e.getMessage()));
        }


        SwingUtilities.invokeLater(new Runnable() {
            public void run() {
                Window.msgBox(propertyFile.content.get(PermaFile.installedPackName)+" successfully installed");
            }
        });
    }
}

