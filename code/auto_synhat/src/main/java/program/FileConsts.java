package program;

import java.io.File;

public final class FileConsts {
    public static final File downloadZipFile = new File("resourcepacks/synhat/temp/synhat.zip");
    public static final File downloadDir = new File("resourcepacks/synhat/temp");
    public static final File assetsDir = new File(downloadDir, "synhat-master/assets");
    public static final File outputDir = new File("resourcepacks/synhat");
    public static final File permanentStorageFile = new File(outputDir,"properties.json");

}
