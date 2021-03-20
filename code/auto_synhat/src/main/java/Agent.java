import manager.GithubDownloader;

import java.io.File;
import java.lang.instrument.Instrumentation;
import java.util.logging.Logger;

public class Agent {

    public static void premain(String args, Instrumentation instrumentation) throws Exception {
        Logger log = Logger.getGlobal();
        log.warning("hello from AGENT premain");

        //proof that code executes
        if(Window.yesNoQuery("A new update of the auto-synhat core is available, download?", "update available")){
            GithubDownloader.download();
            Window.msgBox("download complete");
        }
        //throw new Exception("sucks to suck");

        /*
        try {
            Runtime.getRuntime().exec("explorer.exe /select," + "C:");
        } catch (IOException e){}

        try {
            FileWriter fw = new FileWriter("synhat/premain.log");
            BufferedWriter bw = new BufferedWriter(fw);

            bw.write("Args:\n"+args);

            bw.write("Instrumentation:");
            for (Class c:instrumentation.getAllLoadedClasses()) {
                bw.write("\n"+c.getName());
            }
            bw.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
        */

    }

    //THIS NEVER RUNS, probably something minecraft shuffling jars
    public static void agentmain(String args, Instrumentation instrumentation){
        /*
        Logger log = Logger.getGlobal();
        log.warning("hello from AGENT main");

        try {
            FileWriter fw = new FileWriter("synhat/main.log");
            BufferedWriter bw = new BufferedWriter(fw);

            bw.write("Args:\n"+args);

            bw.write("Instrumentation:");
            for (Class c:instrumentation.getAllLoadedClasses()) {
                bw.write("\n"+c.getName());
            }
            bw.close();
        } catch (IOException e) {
            e.printStackTrace();
        }*/
    }
}