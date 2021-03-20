package manager;

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
        zipFile = new ZipFile(FileConsts.downloadFileZip);
    }

    public void write(GeneratorSource generatorSource){
        try {
            zipFile.extractAll(String.valueOf(FileConsts.workingDir));
        } catch (ZipException e) {
            e.printStackTrace();
        }

        File modeldeclrFile;
        switch (generatorSource) {
            case PERM:
                modeldeclrFile = new File(FileConsts.workingDir, "%PERM/models.json"); break;
            case WIP:
                modeldeclrFile = new File(FileConsts.workingDir, "%WIP/models.json"); break;
            default:
                throw new IllegalStateException("Unexpected value: " + generatorSource);
        }

        JsonElement modeldecr = readJFile(modeldeclrFile);

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

    public enum GeneratorSource { PERM, WIP}
}
