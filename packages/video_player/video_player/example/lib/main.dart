// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

/// An example of using the plugin, controlling lifecycle and playback of the
/// video.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(
    MaterialApp(
      home: _App(),
    ),
  );
}

class _App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        key: const ValueKey<String>('home_page'),
        appBar: AppBar(
          title: const Text('Video player example'),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('push_tab'),
              icon: const Icon(Icons.navigation),
              onPressed: () {
                Navigator.push<_PlayerVideoAndPopPage>(
                  context,
                  MaterialPageRoute<_PlayerVideoAndPopPage>(
                    builder: (BuildContext context) => _PlayerVideoAndPopPage(),
                  ),
                );
              },
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.cloud),
                text: 'Remote',
              ),
              Tab(icon: Icon(Icons.insert_drive_file), text: 'Asset'),
              Tab(icon: Icon(Icons.list), text: 'List example'),
              Tab(icon: Icon(Icons.list), text: 'Download example')
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _BumbleBeeRemoteVideo(),
            _ButterFlyAssetVideo(),
            _ButterFlyAssetVideoInList(),
            _DownloadVideoListWrapper(),
          ],
        ),
      ),
    );
  }
}

class DownloadProgress extends ChangeNotifier {
  DownloadProgress(this.url);

  Map<String, double> progressMap = <String, double>{};
  double progress = 0.0;
  String url = '';

  void updateProgress(String url, double progress) {
    progressMap[url] = progress;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}

class _DownloadVideoListWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DownloadProgress>(
      create: (BuildContext context) => DownloadProgress('asdf'),
      child: _DownloadVideosList(),
    );
  }
}

class _DownloadVideosList extends StatefulWidget {
  @override
  State<_DownloadVideosList> createState() => _DownloadVideosListState();
}

class _DownloadVideosListState extends State<_DownloadVideosList> {
  late VideoPlayerController downloadsController;
  @override
  void initState() {
    downloadsController = VideoPlayerController.networkUrl(
        Uri.parse('https://vs-dev.sisers.seadev-studios.com/ES3KawVfFTvPSoaOrbe3m/stream.m3u8'));

    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      final DownloadProgress t = Provider.of<DownloadProgress>(context, listen: false);
      downloadsController.initDownloadEvents((Download download) {
        t.updateProgress(download.url, download.percentDownloaded);
        log('Downloaded ${download.url}: ${download.percentDownloaded}%');
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        _ExampleDownloadCard(
          title: 'Stretching 1 (3m)',
          url: 'https://vs-dev.sisers.seadev-studios.com/dksUDCxcUP0aIxqA7nLMD/stream.m3u8',
        ),
        _ExampleDownloadCard(
          title: 'Hohoho (69m)',
          url: 'https://vs-dev.sisers.seadev-studios.com/E87Un5n9SUT-kr6o8xJ3h/stream.m3u8',
        ),
        _ExampleDownloadCard(
          title: 'Stretching 2 (11m)',
          url: 'https://vs-dev.sisers.seadev-studios.com/FN1hLbya-T9WTTt0G75IR/stream.m3u8',
        ),
        _ExampleDownloadCard(
          title: 'Stretching 3 (13m)',
          url: 'https://vs-dev.sisers.seadev-studios.com/fF2iglaS0O4gopE4A6mhO/stream.m3u8',
        ),
        _ExampleDownloadCard(
          title: 'Long name (7m)',
          url: 'https://vs-dev.sisers.seadev-studios.com/SDH6ULGVI7zZxqz5rsr-Q/stream.m3u8',
        ),
      ],
    );
  }
}

/// A filler card to show the video in a list of scrolling contents.
class _ExampleDownloadCard extends StatefulWidget {
  _ExampleDownloadCard({required this.title, required this.url});

  final String title;
  final String url;
  late VideoPlayerController _controller;

  @override
  State<_ExampleDownloadCard> createState() => _ExampleDownloadCardState();
}

class _ExampleDownloadCardState extends State<_ExampleDownloadCard> {
  @override
  void initState() {
    widget._controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    widget._controller.getDownload(widget.url).then((Download? systemDownload) {
      if (systemDownload != null) {
        log('$systemDownload.url state:  $systemDownload.state');
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.download_for_offline),
            title: Text(widget.title),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              ButtonBar(children: <Widget>[
                TextButton(
                  child: const Text('Start'),
                  onPressed: () {
                    widget._controller.startDownload(widget.url);
                  },
                ),
                TextButton(
                  child: const Text('Pause'),
                  onPressed: () {
                    widget._controller.stopDownload(widget.url);
                  },
                ),
                TextButton(
                  child: const Text('Remove'),
                  onPressed: () {
                    widget._controller.removeDownload(widget.url);
                    Provider.of<DownloadProgress>(context, listen: false).updateProgress(widget.url, 0.0);
                  },
                ),
              ]),
              _DownloadProgress(widget.url),
            ],
          )
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatefulWidget {
  const _DownloadProgress(this.url);
  final String url;

  @override
  _DownloadProgressState createState() => _DownloadProgressState();
}

class _DownloadProgressState extends State<_DownloadProgress> {
  double progress = 0.0;
  double dlprogress = 0.0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      final DownloadProgress t = Provider.of<DownloadProgress>(context, listen: false);
      t.addListener(() {
        if (t.progressMap.containsKey(widget.url)) {
          setState(() {
            progress = t.progressMap[widget.url]! / 100;
          });
        }
      });
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    if (progress < 1.0) {
      return SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.blue, value: progress));
    } else {
      return const Text('Finished');
    }
  }
}

class _ButterFlyAssetVideoInList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const _ExampleCard(title: 'Item a'),
        const _ExampleCard(title: 'Item b'),
        const _ExampleCard(title: 'Item c'),
        const _ExampleCard(title: 'Item d'),
        const _ExampleCard(title: 'Item e'),
        const _ExampleCard(title: 'Item f'),
        const _ExampleCard(title: 'Item g'),
        Card(
            child: Column(children: <Widget>[
          Column(
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.cake),
                title: Text('Video video'),
              ),
              Stack(alignment: FractionalOffset.bottomRight + const FractionalOffset(-0.1, -0.1), children: <Widget>[
                _ButterFlyAssetVideo(),
                Image.asset('assets/flutter-mark-square-64.png'),
              ]),
            ],
          ),
        ])),
        const _ExampleCard(title: 'Item h'),
        const _ExampleCard(title: 'Item i'),
        const _ExampleCard(title: 'Item j'),
        const _ExampleCard(title: 'Item k'),
        const _ExampleCard(title: 'Item l'),
      ],
    );
  }
}

/// A filler card to show the video in a list of scrolling contents.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.airline_seat_flat_angled),
            title: Text(title),
          ),
          ButtonBar(
            children: <Widget>[
              TextButton(
                child: const Text('BUY TICKETS'),
                onPressed: () {
                  /* ... */
                },
              ),
              TextButton(
                child: const Text('SELL TICKETS'),
                onPressed: () {
                  /* ... */
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ButterFlyAssetVideo extends StatefulWidget {
  @override
  _ButterFlyAssetVideoState createState() => _ButterFlyAssetVideoState();
}

class _ButterFlyAssetVideoState extends State<_ButterFlyAssetVideo> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/Butterfly-209.mp4');

    _controller.addListener(() {
      setState(() {});
    });
    _controller.setLooping(true);
    _controller.initialize().then((_) => setState(() {}));
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(top: 20.0),
          ),
          const Text('With assets mp4'),
          Container(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  VideoPlayer(_controller),
                  _ControlsOverlay(controller: _controller),
                  VideoProgressIndicator(_controller, allowScrubbing: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BumbleBeeRemoteVideo extends StatefulWidget {
  @override
  _BumbleBeeRemoteVideoState createState() => _BumbleBeeRemoteVideoState();
}

class _BumbleBeeRemoteVideoState extends State<_BumbleBeeRemoteVideo> {
  late VideoPlayerController _controller;

  Future<ClosedCaptionFile> _loadCaptions() async {
    final String fileContents = await DefaultAssetBundle.of(context).loadString('assets/bumble_bee_captions.vtt');
    return WebVTTCaptionFile(fileContents); // For vtt files, use WebVTTCaptionFile
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse('https://vs-dev.sisers.seadev-studios.com/dksUDCxcUP0aIxqA7nLMD/stream.m3u8'),
      closedCaptionFile: _loadCaptions(),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.setLooping(true);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(padding: const EdgeInsets.only(top: 20.0)),
          const Text('With remote mp4'),
          Container(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  VideoPlayer(_controller),
                  ClosedCaption(text: _controller.value.caption.text),
                  _ControlsOverlay(controller: _controller),
                  VideoProgressIndicator(_controller, allowScrubbing: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.controller});

  static const List<Duration> _exampleCaptionOffsets = <Duration>[
    Duration(seconds: -10),
    Duration(seconds: -3),
    Duration(seconds: -1, milliseconds: -500),
    Duration(milliseconds: -250),
    Duration.zero,
    Duration(milliseconds: 250),
    Duration(seconds: 1, milliseconds: 500),
    Duration(seconds: 3),
    Duration(seconds: 10),
  ];
  static const List<double> _examplePlaybackRates = <double>[
    0.25,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    5.0,
    10.0,
  ];

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
        Align(
          alignment: Alignment.topLeft,
          child: PopupMenuButton<Duration>(
            initialValue: controller.value.captionOffset,
            tooltip: 'Caption Offset',
            onSelected: (Duration delay) {
              controller.setCaptionOffset(delay);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<Duration>>[
                for (final Duration offsetDuration in _exampleCaptionOffsets)
                  PopupMenuItem<Duration>(
                    value: offsetDuration,
                    child: Text('${offsetDuration.inMilliseconds}ms'),
                  )
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                // Using less vertical padding as the text is also longer
                // horizontally, so it feels like it would need more spacing
                // horizontally (matching the aspect ratio of the video).
                vertical: 12,
                horizontal: 16,
              ),
              child: Text('${controller.value.captionOffset.inMilliseconds}ms'),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: PopupMenuButton<double>(
            initialValue: controller.value.playbackSpeed,
            tooltip: 'Playback speed',
            onSelected: (double speed) {
              controller.setPlaybackSpeed(speed);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<double>>[
                for (final double speed in _examplePlaybackRates)
                  PopupMenuItem<double>(
                    value: speed,
                    child: Text('${speed}x'),
                  )
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                // Using less vertical padding as the text is also longer
                // horizontally, so it feels like it would need more spacing
                // horizontally (matching the aspect ratio of the video).
                vertical: 12,
                horizontal: 16,
              ),
              child: Text('${controller.value.playbackSpeed}x'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerVideoAndPopPage extends StatefulWidget {
  @override
  _PlayerVideoAndPopPageState createState() => _PlayerVideoAndPopPageState();
}

class _PlayerVideoAndPopPageState extends State<_PlayerVideoAndPopPage> {
  late VideoPlayerController _videoPlayerController;
  bool startedPlaying = false;

  @override
  void initState() {
    super.initState();

    _videoPlayerController = VideoPlayerController.asset('assets/Butterfly-209.mp4');
    _videoPlayerController.addListener(() {
      if (startedPlaying && !_videoPlayerController.value.isPlaying) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  Future<bool> started() async {
    await _videoPlayerController.initialize();
    await _videoPlayerController.play();
    startedPlaying = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: FutureBuilder<bool>(
          future: started(),
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if (snapshot.data ?? false) {
              return AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController),
              );
            } else {
              return const Text('waiting for video to load');
            }
          },
        ),
      ),
    );
  }
}
