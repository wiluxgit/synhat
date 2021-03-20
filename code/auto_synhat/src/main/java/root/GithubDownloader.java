package root;

import com.google.gson.*;
import net.lingala.zip4j.ZipFile;
import org.kohsuke.github.GHRelease;
import org.kohsuke.github.GHRepository;
import org.kohsuke.github.GitHub;

import java.io.*;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Scanner;

public class GithubDownloader {
    public static boolean isOutdated() {
        try {
            GitHub github = GitHub.connect();
            github.checkApiUrlValidity();
            GHRepository repo = github.getRepository("OscarDahlqvist/synhat");
            GHRelease latestRelease = repo.getLatestRelease();
            String latestReleaseName = latestRelease.getName();

            String installedReleaseName = Main.propertyFile.content.get(PermaFile.installedPackName).getAsString();

            //Window.msgBox(installedReleaseName + ":" + latestReleaseName);

            return !installedReleaseName.equals(latestReleaseName);
        } catch (IOException e){
            return false;
        }
    }
    public static String downloadLatestZip() throws Exception {
        FileConsts.outputDir.mkdirs();

        try {
            GitHub github = GitHub.connect();
            GHRepository repo = github.getRepository("OscarDahlqvist/synhat");
            GHRelease latestRelease = repo.getLatestRelease();
            String latestReleaseName = latestRelease.getName();

            String latestReleaseUrl = latestRelease.getAssetsUrl();

            JsonParser jsonParser = new JsonParser();
            String releaseApiString = downloadStringFromURL(latestReleaseUrl);
            JsonArray releaseApiJson = jsonParser.parse(releaseApiString).getAsJsonArray();

            JsonObject releaseReleaseZipJson = releaseApiJson.get(0).getAsJsonObject();
            String releaseFileName = releaseReleaseZipJson.getAsJsonObject().get("name").getAsString();

            if(!releaseFileName.equals("release.zip")) throw new Exception("Invalid File Json");

            String latestReleaseDownloadUrl = releaseReleaseZipJson.get("browser_download_url").getAsString();

            copyURLToFile(new URL(latestReleaseDownloadUrl), FileConsts.downloadZipFile);

            Main.propertyFile.content.add(PermaFile.installedPackName, new JsonPrimitive(latestReleaseName));
            //TODO: save creation date
            Main.propertyFile.save();

            return latestReleaseName;

        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }

    public static void unzip() throws IOException {

        ZipFile zipFile = new ZipFile(FileConsts.downloadZipFile);
        zipFile.extractAll(FileConsts.outputDir.getPath());
    }

    private static String downloadStringFromURL(String requestURL) throws IOException    {
        try (Scanner scanner = new Scanner(new URL(requestURL).openStream(),
                StandardCharsets.UTF_8.toString()))
        {
            scanner.useDelimiter("\\A");
            return scanner.hasNext() ? scanner.next() : "";
        }
    }

    private static void copyURLToFile(URL url, File file) {
        file.getParentFile().mkdirs();

        try {
            InputStream input = url.openStream();
            if (file.exists()) {
                if (file.isDirectory())
                    throw new IOException("File '" + file + "' is a directory");

                if (!file.canWrite())
                    throw new IOException("File '" + file + "' cannot be written");
            } else {
                File parent = file.getParentFile();
                if ((parent != null) && (!parent.exists()) && (!parent.mkdirs())) {
                    throw new IOException("File '" + file + "' could not be created");
                }
            }

            FileOutputStream output = new FileOutputStream(file);

            byte[] buffer = new byte[4096];
            int n = 0;
            while (-1 != (n = input.read(buffer))) {
                output.write(buffer, 0, n);
            }

            input.close();
            output.close();

            System.out.println("File '" + file + "' downloaded successfully!");
        }
        catch(IOException ioEx) {
            ioEx.printStackTrace();
        }
    }
}