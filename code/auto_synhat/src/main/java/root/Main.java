package root;

import javax.swing.*;
import java.lang.instrument.Instrumentation;
import java.util.logging.Logger;

public class Main {
    public static boolean argBeta = false;
    public static boolean argShowDownload = false;
    public static PermaFile propertyFile;

    public static void premain(String args, Instrumentation instrumentation) throws Exception {
        Logger log = Logger.getGlobal();
        log.warning("Synhat is enabled");

        if(args != null){
            for (String s: args.split(",")){
                if (s.equals("beta")) argBeta = true;
                if (s.equals("slow")) argShowDownload = true;
            }
        }

        propertyFile = new PermaFile(FileConsts.permanentStorageFile);

        DownloadThread downloadThread = new DownloadThread();
        if(argShowDownload){
            downloadThread.run();

            SwingUtilities.invokeLater(new Runnable() {
                public void run() {
                    Window.msgBox("Synhat "+propertyFile.content.get(PermaFile.installedPackName)+" sucesfully installed");
                }
            });
        } else {
            Thread t = new Thread(downloadThread);
            t.start();
            //TODO: make it possible to send popups from here
        }
    }

    //THIS NEVER RUNS, but it is still required.
    public static void agentmain(String args, Instrumentation instrumentation){}
}

//runs in a separate thread so to not slow down minecraft
class DownloadThread implements Runnable {
    DownloadThread() {}

    public void run() {
        boolean isOutdated = GithubDownloader.isOutdated();
        if(isOutdated){
            try {
                String vname = GithubDownloader.downloadLatestZip();
                GithubDownloader.unzip();
            } catch (Exception e) {}
        }
    }
}