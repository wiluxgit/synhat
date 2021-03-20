package manager;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonParser;
import net.lingala.zip4j.ZipFile;
import net.lingala.zip4j.exception.ZipException;

import java.io.File;
import java.io.FileReader;
import java.io.IOException;

public class Generator {
    ZipFile zipFile;

    public Generator(){
        System.out.println("Generator run");
        FileConsts.downloadDir.mkdirs();
        FileConsts.outputDir.mkdirs();
        FileConsts.assetsDir.mkdirs();
        zipFile = new ZipFile(FileConsts.downloadFileZip);
    }

    public void write(GeneratorSource generatorSource){
        try {
            zipFile.extractAll(String.valueOf(FileConsts.downloadDir));
        } catch (ZipException e) {
            e.printStackTrace();
        }

        File modeldeclrFile;
        switch (generatorSource) {
            case PERM:
                modeldeclrFile = new File(FileConsts.assetsDir, "%PERM/models.json"); break;
            case WIP:
                modeldeclrFile = new File(FileConsts.assetsDir, "%WIP/models.json"); break;
            default:
                throw new IllegalStateException("Unexpected value: " + generatorSource);
        }

        JsonArray modeldeclr = readJFile(modeldeclrFile).getAsJsonObject().get("models").getAsJsonArray();
        Window.msgBox(modeldeclr.toString());
    }
    public JsonElement readJFile(File file){
        Window.msgBox(file.getAbsolutePath());
        JsonParser jsonParser = new JsonParser();

        try (FileReader reader = new FileReader(file))
        {
            //Read JSON file
            return jsonParser.parse(reader);

        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }

    public enum GeneratorSource {PERM, WIP}
}
