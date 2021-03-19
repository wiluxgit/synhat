import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.instrument.Instrumentation;
import java.nio.file.Path;
import java.util.logging.Logger;

public class Agent {
    public static void premain(String args, Instrumentation instrumentation){
        Logger log = Logger.getGlobal();
        log.warning("hello from AGENT premain");

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
    }

    public static void agentmain(String args, Instrumentation instrumentation){
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
        }
    }
}