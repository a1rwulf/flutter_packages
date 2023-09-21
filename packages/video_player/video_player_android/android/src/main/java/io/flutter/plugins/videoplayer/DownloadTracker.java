/*
 * Copyright (C) 2017 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.flutter.plugins.videoplayer;

import static com.google.common.base.Preconditions.checkNotNull;

import android.content.Context;
import android.net.Uri;
import androidx.annotation.Nullable;
import com.google.android.exoplayer2.DefaultRenderersFactory;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.offline.Download;
import com.google.android.exoplayer2.offline.DownloadCursor;
import com.google.android.exoplayer2.offline.DownloadHelper;
import com.google.android.exoplayer2.offline.DownloadHelper.LiveContentUnsupportedException;
import com.google.android.exoplayer2.offline.DownloadIndex;
import com.google.android.exoplayer2.offline.DownloadManager;
import com.google.android.exoplayer2.offline.DownloadRequest;
import com.google.android.exoplayer2.offline.DownloadService;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.util.Log;
import com.google.android.exoplayer2.util.Util;
import java.io.IOException;
import java.util.HashMap;
import java.util.concurrent.CopyOnWriteArraySet;

/**
 * Tracks media that has been downloaded.
 *
 * @deprecated com.google.android.exoplayer2 is deprecated. Please migrate to androidx.media3 (which
 *     contains the same ExoPlayer code). See <a
 *     href="https://developer.android.com/guide/topics/media/media3/getting-started/migration-guide">the
 *     migration guide</a> for more details, including a script to help with the migration.
 */
@Deprecated
public class DownloadTracker {

  /** Listens for changes in the tracked downloads. */
  public interface Listener {

    /** Called when the tracked downloads changed. */
    void onDownloadsChanged();
  }

  private static final String TAG = "DownloadTracker";

  private final Context context;
  private final DataSource.Factory dataSourceFactory;
  private final CopyOnWriteArraySet<Listener> listeners;
  private final HashMap<Uri, Download> downloads;
  private final DownloadIndex downloadIndex;

  @Nullable private StartDownloadHelper startDownloadHelper;

  public DownloadTracker(
      Context context, DataSource.Factory dataSourceFactory, DownloadManager downloadManager) {
    this.context = context.getApplicationContext();
    this.dataSourceFactory = dataSourceFactory;
    listeners = new CopyOnWriteArraySet<>();
    downloads = new HashMap<>();
    downloadIndex = downloadManager.getDownloadIndex();
    downloadManager.addListener(new DownloadManagerListener());
    loadDownloads();
  }

  public void addListener(Listener listener) {
    listeners.add(checkNotNull(listener));
  }

  public void removeListener(Listener listener) {
    listeners.remove(listener);
  }

  public boolean isDownloaded(MediaItem mediaItem) {
    @Nullable Download download = downloads.get(checkNotNull(mediaItem.localConfiguration).uri);
    return download != null && download.state != Download.STATE_FAILED;
  }

  @Nullable
  public DownloadRequest getDownloadRequest(Uri uri) {
    @Nullable Download download = downloads.get(uri);
    return download != null && download.state != Download.STATE_FAILED ? download.request : null;
  }

  @Nullable
  public Download getDownload(String uri) {
    MediaItem mediaItem = MediaItem.fromUri(uri);
    @Nullable Download download = downloads.get(checkNotNull(mediaItem.localConfiguration).uri);
    return download;
  }

  // public void toggleDownload(String uri) {
  //   MediaItem mediaItem = MediaItem.fromUri(uri);
  //   @Nullable Download download = downloads.get(checkNotNull(mediaItem.localConfiguration).uri);
  //   if (download != null && download.state != Download.STATE_FAILED) {
  //       Log.d(TAG, "Download already started or finished");
  //   } else {
  //     if (startDownloadHelper != null) {
  //       startDownloadHelper.release();
  //     }
  //     startDownloadHelper =
  //         new StartDownloadHelper(
  //             DownloadHelper.forMediaItem(context, mediaItem, new
  // DefaultRenderersFactory(context), dataSourceFactory),
  //             mediaItem);
  //   }
  // }

  public void startDownload(String uri) {
    MediaItem mediaItem = MediaItem.fromUri(uri);
    @Nullable Download download = downloads.get(checkNotNull(mediaItem.localConfiguration).uri);
    if (download != null && download.state != Download.STATE_FAILED) {
      if (download != null && download.state == Download.STATE_STOPPED) {
        Log.d(TAG, "Download in stopped state - reset stop reason...");
        DownloadService.sendSetStopReason(
            context,
            VideoPlayerDownloadService.class,
            download.request.id,
            0,
            /* foreground= */ false);
      } else {
        Log.d(TAG, "Download state: " + download.state + " skip start...");
      }
    } else {
      if (startDownloadHelper != null) {
        startDownloadHelper.release();
      }
      startDownloadHelper =
          new StartDownloadHelper(
              DownloadHelper.forMediaItem(
                  context, mediaItem, new DefaultRenderersFactory(context), dataSourceFactory),
              mediaItem);
    }
  }

  public void stopDownload(String uri) {
    MediaItem mediaItem = MediaItem.fromUri(uri);
    @Nullable Download download = downloads.get(checkNotNull(mediaItem.localConfiguration).uri);
    if (download != null && download.state != Download.STATE_FAILED) {
      Log.d(TAG, "Download already started or finished - stop it...");
      DownloadService.sendSetStopReason(
          context,
          VideoPlayerDownloadService.class,
          download.request.id,
          1,
          /* foreground= */ false);
    }
  }

  public void removeDownload(String uri) {
    MediaItem mediaItem = MediaItem.fromUri(uri);
    @Nullable Download download = downloads.get(checkNotNull(mediaItem.localConfiguration).uri);
    if (download != null && download.state != Download.STATE_FAILED) {
      Log.d(TAG, "Download already started or finished - remove it...");
      DownloadService.sendRemoveDownload(
          context, VideoPlayerDownloadService.class, download.request.id, /* foreground= */ false);
    }
  }

  private void loadDownloads() {
    try (DownloadCursor loadedDownloads = downloadIndex.getDownloads()) {
      while (loadedDownloads.moveToNext()) {
        Download download = loadedDownloads.getDownload();
        downloads.put(download.request.uri, download);
        Log.w(TAG, "Download found: " + download.request.uri);
      }
    } catch (IOException e) {
      Log.w(TAG, "Failed to query downloads", e);
    }
  }

  private class DownloadManagerListener implements DownloadManager.Listener {

    @Override
    public void onDownloadChanged(
        DownloadManager downloadManager, Download download, @Nullable Exception finalException) {
      downloads.put(download.request.uri, download);
      for (Listener listener : listeners) {
        listener.onDownloadsChanged();
      }
    }

    @Override
    public void onDownloadRemoved(DownloadManager downloadManager, Download download) {
      downloads.remove(download.request.uri);
      for (Listener listener : listeners) {
        listener.onDownloadsChanged();
      }
    }
  }

  private final class StartDownloadHelper implements DownloadHelper.Callback {

    private final DownloadHelper downloadHelper;
    private final MediaItem mediaItem;

    @Nullable private byte[] keySetId;

    public StartDownloadHelper(DownloadHelper downloadHelper, MediaItem mediaItem) {
      this.downloadHelper = downloadHelper;
      this.mediaItem = mediaItem;
      downloadHelper.prepare(this);
    }

    public void release() {
      downloadHelper.release();
    }

    // DownloadHelper.Callback implementation.

    @Override
    public void onPrepared(DownloadHelper helper) {
      onDownloadPrepared(helper);
      return;
    }

    @Override
    public void onPrepareError(DownloadHelper helper, IOException e) {
      boolean isLiveContent = e instanceof LiveContentUnsupportedException;
      String logMessage =
          isLiveContent ? "Downloading live content unsupported" : "Failed to start download";
      Log.e(TAG, logMessage, e);
    }

    // Internal methods.

    private void onOfflineLicenseFetched(DownloadHelper helper, byte[] keySetId) {
      this.keySetId = keySetId;
      onDownloadPrepared(helper);
    }

    private void onDownloadPrepared(DownloadHelper helper) {
      Log.d(TAG, "No periods found. Downloading entire stream.");
      startDownload();
      downloadHelper.release();
      return;
    }

    private void startDownload() {
      startDownload(buildDownloadRequest());
    }

    private void startDownload(DownloadRequest downloadRequest) {
      Log.d(TAG, "Call DownloadService sendAddDownload...");
      DownloadService.sendAddDownload(
          context, VideoPlayerDownloadService.class, downloadRequest, /* foreground= */ false);
    }

    private DownloadRequest buildDownloadRequest() {
      Log.d(TAG, "Build DownloadRequest for " + mediaItem.localConfiguration.uri);
      return downloadHelper
          .getDownloadRequest(
              Util.getUtf8Bytes(checkNotNull(mediaItem.localConfiguration).uri.toString()))
          .copyWithKeySetId(keySetId);
    }
  }
}
