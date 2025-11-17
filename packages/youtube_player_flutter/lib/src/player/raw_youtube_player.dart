// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../enums/player_state.dart';
import '../utils/youtube_meta_data.dart';
import '../utils/youtube_player_controller.dart';

/// A raw youtube player widget which interacts with the underlying webview inorder to play YouTube videos.
///
/// Use [YoutubePlayer] instead.
class RawYoutubePlayer extends StatefulWidget {
  /// Creates a [RawYoutubePlayer] widget.
  const RawYoutubePlayer({
    super.key,
    this.onEnded,
  });

  /// {@macro youtube_player_flutter.onEnded}
  final void Function(YoutubeMetaData metaData)? onEnded;

  @override
  State<RawYoutubePlayer> createState() => _RawYoutubePlayerState();
}

class _RawYoutubePlayerState extends State<RawYoutubePlayer>
    with WidgetsBindingObserver {
  YoutubePlayerController? controller;
  PlayerState? _cachedPlayerState;
  bool _isPlayerReady = false;
  bool _onLoadStopCalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_cachedPlayerState != null &&
            _cachedPlayerState == PlayerState.playing) {
          controller?.play();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        _cachedPlayerState = controller!.value.playerState;
        controller?.pause();
        break;
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    controller = YoutubePlayerController.of(context);
    return IgnorePointer(
      ignoring: true,
      child: InAppWebView(
        key: widget.key,
        initialData: InAppWebViewInitialData(
          data: player,
          encoding: 'utf-8',
          baseUrl: WebUri.uri(Uri.https('youtube-nocookie.com')),
          mimeType: 'text/html',
        ),
        initialSettings: InAppWebViewSettings(
          userAgent: userAgent,
          mediaPlaybackRequiresUserGesture: false,
          transparentBackground: true,
          disableContextMenu: true,
          supportZoom: false,
          disableHorizontalScroll: false,
          disableVerticalScroll: false,
          allowsInlineMediaPlayback: true,
          allowsAirPlayForMediaPlayback: true,
          allowsPictureInPictureMediaPlayback: true,
          useWideViewPort: false,
          useHybridComposition: controller!.flags.useHybridComposition,
        ),
        onWebViewCreated: (webController) {
          controller!.updateValue(
            controller!.value.copyWith(webViewController: webController),
          );
          webController
            ..addJavaScriptHandler(
              handlerName: 'Ready',
              callback: (_) {
                _isPlayerReady = true;
                if (_onLoadStopCalled) {
                  controller!.updateValue(
                    controller!.value.copyWith(isReady: true),
                  );
                }
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'StateChange',
              callback: (args) {
                switch (args.first as int) {
                  case -1:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.unStarted,
                        isLoaded: true,
                      ),
                    );
                    break;
                  case 0:
                    widget.onEnded?.call(controller!.metadata);
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.ended,
                      ),
                    );
                    break;
                  case 1:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.playing,
                        isPlaying: true,
                        hasPlayed: true,
                        errorCode: 0,
                      ),
                    );
                    break;
                  case 2:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.paused,
                        isPlaying: false,
                      ),
                    );
                    break;
                  case 3:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.buffering,
                      ),
                    );
                    break;
                  case 5:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.cued,
                      ),
                    );
                    break;
                  default:
                    throw Exception("Invalid player state obtained.");
                }
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'PlaybackQualityChange',
              callback: (args) {
                controller!.updateValue(
                  controller!.value
                      .copyWith(playbackQuality: args.first as String),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'PlaybackRateChange',
              callback: (args) {
                final num rate = args.first;
                controller!.updateValue(
                  controller!.value.copyWith(playbackRate: rate.toDouble()),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'Errors',
              callback: (args) {
                final errorCode = args.first is int
                    ? args.first
                    : int.tryParse(args.first) ?? -1;
                controller!.updateValue(
                  controller!.value.copyWith(errorCode: errorCode),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'VideoData',
              callback: (args) {
                controller!.updateValue(
                  controller!.value.copyWith(
                      metaData: YoutubeMetaData.fromRawData(args.first)),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'VideoTime',
              callback: (args) {
                final position = args.first * 1000;
                final num buffered = args.last;
                controller!.updateValue(
                  controller!.value.copyWith(
                    position: Duration(milliseconds: position.floor()),
                    buffered: buffered.toDouble(),
                  ),
                );
              },
            );
        },
        onLoadStop: (_, __) {
          _onLoadStopCalled = true;
          if (_isPlayerReady) {
            controller!.updateValue(
              controller!.value.copyWith(isReady: true),
            );
          }
        },
      ),
    );
  }

  String get player => '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            html,
            body {
                margin: 0;
                padding: 0;
                background-color: #000000;
                overflow: hidden;
                position: fixed;
                height: 100%;
                width: 100%;
                pointer-events: none;
            }

            /* Hide YouTube player controls globally */
            iframe {
                pointer-events: auto;
            }

            /* Add overlay to hide bottom controls area */
            #player {
                position: relative;
                height: 100%;
                width: 100%;
            }

            #player::after {
                content: '';
                position: absolute;
                bottom: 0;
                left: 0;
                right: 0;
                height: 60px;
                background: transparent;
                pointer-events: none;
                z-index: 9999;
            }

            /* Try to hide controls with aggressive CSS */
            #player iframe {
                overflow: hidden !important;
            }
        </style>
        <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>
    </head>
    <body>
        <div id="player"></div>
        <script>
            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
            var player;
            var timerId;
            function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                    height: '100%',
                    width: '100%',
                    videoId: '${controller!.initialVideoId}',
                    playerVars: {
                        'controls': 0,
                        'playsinline': 1,
                        'enablejsapi': 1,
                        'fs': 0,
                        'rel': 0,
                        'showinfo': 0,
                        'iv_load_policy': 3,
                        'modestbranding': 1,
                        'cc_load_policy': ${boolean(value: controller!.flags.enableCaption)},
                        'cc_lang_pref': '${controller!.flags.captionLanguage}',
                        'autoplay': ${boolean(value: controller!.flags.autoPlay)},
                        'start': ${controller!.flags.startAt},
                        'end': ${controller!.flags.endAt}
                    },
                    events: {
                        onReady: function(event) {
                            window.flutter_inappwebview.callHandler('Ready');
                            hideYouTubeControls();
                        },
                        onStateChange: function(event) {
                            sendPlayerStateChange(event.data);
                            hideYouTubeControls();
                        },
                        onPlaybackQualityChange: function(event) { window.flutter_inappwebview.callHandler('PlaybackQualityChange', event.data); },
                        onPlaybackRateChange: function(event) { window.flutter_inappwebview.callHandler('PlaybackRateChange', event.data); },
                        onError: function(error) { window.flutter_inappwebview.callHandler('Errors', error.data); }
                    },
                });
            }

            function hideYouTubeControls() {
                try {
                    var iframe = document.querySelector('iframe');
                    if (iframe) {
                        // Try to access iframe document and inject CSS
                        // Note: This will fail due to CORS policy, but we try anyway
                        try {
                            var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                            if (iframeDoc) {
                                var style = iframeDoc.getElementById('hide-controls-style');
                                if (!style) {
                                    style = iframeDoc.createElement('style');
                                    style.id = 'hide-controls-style';
                                    style.innerHTML = '#player-controls { display: none !important; } .ytp-chrome-top { display: none !important; } .ytp-title { display: none !important; } .ytp-gradient-top { display: none !important; } .ytp-pause-overlay { display: none !important; }';
                                    iframeDoc.head.appendChild(style);
                                    console.log('✓ CSS injected successfully!');
                                }
                            }
                        } catch (e) {
                            // CORS blocks access - this is expected and normal
                            // The Flutter overlay will handle hiding controls instead
                        }
                    }
                } catch (e) {
                    // Ignore errors
                }
            }

            // Attempt CSS injection periodically (will mostly fail due to CORS)
            setInterval(hideYouTubeControls, 100);

            function sendPlayerStateChange(playerState) {
                clearTimeout(timerId);
                window.flutter_inappwebview.callHandler('StateChange', playerState);
                if (playerState == 1) {
                    startSendCurrentTimeInterval();
                    sendVideoData(player);
                }
            }

            function sendVideoData(player) {
                var videoData = {
                    'duration': player.getDuration(),
                    'title': player.getVideoData().title,
                    'author': player.getVideoData().author,
                    'videoId': player.getVideoData().video_id
                };
                window.flutter_inappwebview.callHandler('VideoData', videoData);
            }

            function startSendCurrentTimeInterval() {
                timerId = setInterval(function () {
                    window.flutter_inappwebview.callHandler('VideoTime', player.getCurrentTime(), player.getVideoLoadedFraction());
                }, 100);
            }

            function play() {
                player.playVideo();
                return '';
            }

            function pause() {
                player.pauseVideo();
                return '';
            }

            function loadById(loadSettings) {
                player.loadVideoById(loadSettings);
                return '';
            }

            function cueById(cueSettings) {
                player.cueVideoById(cueSettings);
                return '';
            }

            function loadPlaylist(playlist, index, startAt) {
                player.loadPlaylist(playlist, 'playlist', index, startAt);
                return '';
            }

            function cuePlaylist(playlist, index, startAt) {
                player.cuePlaylist(playlist, 'playlist', index, startAt);
                return '';
            }

            function mute() {
                player.mute();
                return '';
            }

            function unMute() {
                player.unMute();
                return '';
            }

            function setVolume(volume) {
                player.setVolume(volume);
                return '';
            }

            function seekTo(position, seekAhead) {
                player.seekTo(position, seekAhead);
                return '';
            }

            function setSize(width, height) {
                player.setSize(width, height);
                return '';
            }

            function setPlaybackRate(rate) {
                player.setPlaybackRate(rate);
                return '';
            }

            function setTopMargin(margin) {
                document.getElementById("player").style.marginTop = margin;
                return '';
            }
        </script>
    </body>
    </html>
  ''';

  String boolean({required bool value}) => value == true ? "'1'" : "'0'";

  String get userAgent => controller!.flags.forceHD
      ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36'
      : '';
}
