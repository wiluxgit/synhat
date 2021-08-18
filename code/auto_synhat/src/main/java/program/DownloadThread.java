package program;

//runs in a separate thread so to not slow down minecraft
class DownloadThread implements Runnable {
    DownloadThread() {
    }

    public void run() {
        boolean isOutdated = GithubDownloader.isOutdated();
        if (isOutdated) {
            try {
                String vname = GithubDownloader.downloadLatestZip();
                GithubDownloader.unzip();
            } catch (Exception e) {
            }
        }
    }
}
