import manager.Generator;
import manager.GithubDownloader;
import manager.Window;

import java.lang.instrument.Instrumentation;
import java.util.logging.Logger;

public class Agent {

    public static void premain(String args, Instrumentation instrumentation) throws Exception {
        Logger log = Logger.getGlobal();
        log.warning("hello from AGENT premain");

        //proof that code executes
        if(Window.yesNoQuery("BETA: Download synhat?", "Update Available")){
            //GithubDownloader.download();
            //Window.msgBox("download complete");
            Generator generator = new Generator();
            generator.write(Generator.GeneratorSource.PERM);
            Window.msgBox("generator complete");
        }
        throw new Exception("sucks to suck");

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

    //THIS NEVER RUNS, but it is still required.
    public static void agentmain(String args, Instrumentation instrumentation){}
}