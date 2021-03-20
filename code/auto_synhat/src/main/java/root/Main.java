package root;

import java.lang.instrument.Instrumentation;
import java.util.logging.Logger;

public class Main {
    public static boolean argBeta = false;
    public static PermaFile propertyFile;

    public static void premain(String args, Instrumentation instrumentation) throws Exception {
        Logger log = Logger.getGlobal();
        log.warning("hello from AGENT premain");

        for (String s: args.split(",")){
            if (s.equals("beta")) argBeta = true;
        }

        propertyFile = new PermaFile(FileConsts.permanentStorageFile);

        if(GithubDownloader.downloadLatestZipIfOutdated()
                == GithubDownloader.ReleaseDownloadStatus.NewReleaseDownloaded){
            GithubDownloader.unzip();
        }

        for (int i = 0; i < 3; i++) {
            System.out.println(".");
        }
        if (true) throw new Exception("SUCESS");
    }

    //THIS NEVER RUNS, but it is still required.
    public static void agentmain(String args, Instrumentation instrumentation){}
}