package program;

import com.google.gson.*;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;

public class PermaFile {
    private static final SimpleDateFormat installTimeDateFormat = new SimpleDateFormat("yyyy.MM.dd.HH.mm.ss");

    public static final String installedPackName = "installed_pack_name";
    public static final String installedPackTime = "installed_pack_time";

    public JsonObject content;
    File fileLocation;

    public PermaFile(File location) throws IOException {
        fileLocation = location;

        if(!fileLocation.exists()){
            fileLocation.getParentFile().mkdirs();
            fileLocation.createNewFile();

            JsonObject defaultJson = new JsonObject();
            defaultJson.add(installedPackName, new JsonPrimitive("nothing"));
            defaultJson.add(installedPackTime,
                    new JsonPrimitive(installTimeDateFormat.format(System.currentTimeMillis()))
            );

            content = defaultJson.getAsJsonObject();

            save();
        } else {
            JsonParser jsonParser = new JsonParser();
            try (FileReader reader = new FileReader(fileLocation)) {
                content = jsonParser.parse(reader).getAsJsonObject();
            } catch (IOException e) {
                throw new IOException(e);
            }
        }
    }

    public void save(){
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        try (FileWriter writer = new FileWriter(fileLocation)) {
            gson.toJson(content, writer);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
