package manager;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.lingala.zip4j.ZipFile;
import net.lingala.zip4j.exception.ZipException;

import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.Iterator;

public class Generator {
    ZipFile zipFile;

    public Generator(){
        System.out.println("Generator run");
        FileConsts.downloadDir.mkdirs();
        FileConsts.outputDir.mkdirs();
        FileConsts.assetsDir.mkdirs();
        zipFile = new ZipFile(FileConsts.downloadZipFile);
    }

    public void write(boolean keepSourcePyScripts){
        try {
            zipFile.extractAll(String.valueOf(FileConsts.downloadDir));
        } catch (ZipException e) {
            e.printStackTrace();
        }

        File modeldeclrFile = FileConsts.modelDeclrFile;

        JsonArray modeldeclrs = readJFile(modeldeclrFile).getAsJsonObject().get("models").getAsJsonArray();

        for (Iterator<JsonElement> it = modeldeclrs.iterator(); it.hasNext(); ) {
            JsonObject o = it.next().getAsJsonObject();
            o.get()
        }
    }
    public JsonElement readJFile(File file){
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
