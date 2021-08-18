package agent;

import program.Main;
import program.Window;

import javax.swing.*;
import java.io.IOException;
import java.lang.instrument.Instrumentation;
import java.util.logging.Logger;

public class AgentMain {

    public static void premain(String agentArgs, Instrumentation instrumentation) throws Exception {

        String jarPath = AgentMain.class.getProtectionDomain().getCodeSource().getLocation().toURI().getPath();
        String jarName = jarPath.substring(jarPath.lastIndexOf("/") + 1);
        String separator = System.getProperty("file.separator");
        String classpath = System.getProperty("java.class.path"); //gets the source classpath, not agents
        String path = System.getProperty("java.home")
                + separator + "bin" + separator + "java";

        String programArg = "";
        if(agentArgs != null) {
            programArg = "agentArgs="+agentArgs;
        }
        ProcessBuilder processBuilder =
                new ProcessBuilder(
                        path,
                        "-jar",
                        jarName,
                        programArg
                );
        try {
            processBuilder.start();
            //do i need to terminate something here?

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    //THIS NEVER RUNS, but it is still required.
    public static void agentmain(String args, Instrumentation instrumentation){}
}