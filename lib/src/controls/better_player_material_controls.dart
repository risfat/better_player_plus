import 'dart:async';
import 'dart:math';
import 'package:better_player_plus/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player_plus/src/controls/better_player_clickable_widget.dart';
import 'package:better_player_plus/src/controls/better_player_controls_state.dart';
import 'package:better_player_plus/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player_plus/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player_plus/src/controls/better_player_progress_colors.dart';
import 'package:better_player_plus/src/core/better_player_controller.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/video_player/video_player.dart'; // Flutter imports:
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:flutter/material.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerMaterialControls(
      {super.key,
      required this.onControlsVisibilityChanged,
      required this.controlsConfiguration});

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  bool _isLooping = false;
  double _brightness = 0.5;
  double _volume = 0.5;
  double _verticalDragStartY = 0.0;
  double _horizontalDragStartX = 0.0;
  double _accumulatedDelta = 0.0;
  double _verticalDragSensitivity = 200.0; // Higher sensitivity value for smoother control
  double _horizontalDragSensitivity = 5.0;
  bool _showBrightnessVolumeOverlay = false;
  String _overlayText = "";
  Timer? _overlayHideTimer;

  bool _showLeftDoubleTapIcon = false;
  bool _showRightDoubleTapIcon = false;
  Timer? _doubleTapIconHideTimer;

  int _leftDoubleTapCount = 0;
  int _rightDoubleTapCount = 0;
  Timer? _resetDoubleTapCountTimer;

  bool _isSeeking = false;
  Duration _seekPosition = Duration.zero;


  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  void _initializeSettings() async {
    // Initialize brightness and volume
    _brightness = await ScreenBrightness().current;
    _volume = await VolumeController().getVolume();
    VolumeController().showSystemUI = false;
  }
  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }
    return GestureDetector(
      onTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible
            ? cancelAndRestartTimer()
            : changePlayerControlsNotVisible(true);
      },
      onDoubleTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
        }
        cancelAndRestartTimer();
      },
      onLongPress: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
        }
      },
      onDoubleTapDown: (details) {
        _handleDoubleTap(details);
      },
      onVerticalDragStart: (details) {
        if(_betterPlayerController!.controlsEnabled){
          _verticalDragStartY = details.globalPosition.dy;
          _accumulatedDelta = 0.0;
        }
      },
      onVerticalDragUpdate: (details) {
        if(_betterPlayerController!.controlsEnabled){
          final screenSize = MediaQuery
              .of(context)
              .size;
          final dx = details.globalPosition.dx;
          final dy = details.globalPosition.dy;

          // Calculate the difference in the Y axis
          final verticalDragDelta = dy - _verticalDragStartY;

          // Accumulate the delta for smoother changes
          _accumulatedDelta += verticalDragDelta;
          _verticalDragStartY = dy; // Reset startY to the current position

          // Calculate the angle of the gesture
          final angle = atan2(verticalDragDelta.abs(), details.delta.dx.abs());

          if(_betterPlayerController!.isFullScreen){ // Check if the gesture is primarily vertical
            if (angle > pi / 4) {
              final changeAmount = _accumulatedDelta / _verticalDragSensitivity;
              if (dx < screenSize.width / 4) {
                // Left side: control brightness
                _adjustBrightness(-changeAmount);
              } else if (dx > 3 * screenSize.width / 4) {
                // Right side: control volume
                _adjustVolume(-changeAmount);
              }
              _accumulatedDelta = 0.0; // Reset delta after applying change
            }
          }
        }
      },
      onVerticalDragEnd: (details) {
        if(_betterPlayerController!.controlsEnabled && !_betterPlayerController!.isFullScreen){
          final screenSize = MediaQuery
              .of(context)
              .size;
          final dy = details.primaryVelocity ?? 0.0;
          // final verticalThreshold = screenSize.height * 0.05;

          print(
              "Vertical Drag End Detected: dy=$dy, startY=$_verticalDragStartY, screenHeight=${screenSize
                  .height}");

          // Swipe up gesture for fullscreen regardless of current fullscreen state
          if (dy < 0) { // Only consider upward swipes
            // Trigger fullscreen action
            _toggleFullscreen();
          }
        }
      },
      // onVerticalDragEnd: (details) {
      //   final screenSize = MediaQuery.of(context).size;
      //   final dy = details.primaryVelocity ?? 0.0;
      //
      //   print("Vertical Drag End Detected: dy=$dy, startY=$_verticalDragStartY, screenHeight=${screenSize.height}");
      //
      //   // Only consider upward swipes
      //   if (dy < 0) { // Check for upward swipe
      //     print("Vertical Drag End: Swipe Up Detected");
      //     // Ensure the swipe started in the vertical center of the screen
      //     if (_verticalDragStartY > screenSize.height * 0.05) {
      //       print("Triggering fullscreen action");
      //       _toggleFullscreen();
      //     }
      //   }
      // },

      onHorizontalDragStart: (details) {
        if (_betterPlayerController!.controlsEnabled){
          _horizontalDragStartX = details.globalPosition.dx;
          _seekPosition = _controller?.value.position ?? Duration.zero;
          _isSeeking = true;
        }
      },
      onHorizontalDragUpdate: (details) {
        if(_betterPlayerController!.controlsEnabled){
          final horizontalDragDelta = details.globalPosition.dx -
              _horizontalDragStartX;
          _horizontalDragStartX = details.globalPosition.dx;

          final changeInSeconds = (horizontalDragDelta /
              _horizontalDragSensitivity).round();
          _seekPosition += Duration(seconds: changeInSeconds);

          final videoDuration = _controller?.value.duration ?? Duration.zero;

          // Clamp the _seekPosition within the video duration
          if (_seekPosition < Duration.zero) {
            _seekPosition = Duration.zero;
          } else if (_seekPosition > videoDuration) {
            _seekPosition = videoDuration;
          }

          _showSeekOverlay();
        }
      },
      onHorizontalDragEnd: (details) {
        if (_betterPlayerController!.controlsEnabled){
          _controller?.seekTo(_seekPosition);
          _hideSeekOverlay();
        }
      },
      child: AbsorbPointer(
        absorbing: controlsNotVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_wasLoading)
              Center(child: _buildLoadingWidget())
            else
              _buildHitArea(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
            _buildNextVideoWidget(),
            if (_isSeeking) _buildSeekOverlay(),
            if (_showBrightnessVolumeOverlay) _buildBrightnessVolumeOverlay(),
            if (_showLeftDoubleTapIcon) _buildLeftDoubleTapIcon(),
            if (_showRightDoubleTapIcon) _buildRightDoubleTapIcon(),
          ],
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    if (_betterPlayerController != null) {
      if (_betterPlayerController!.isFullScreen) {
        _betterPlayerController!.exitFullScreen();
      } else {
        _betterPlayerController!.enterFullScreen();
      }
    }
  }

  void _showSeekOverlay() {
    _showBrightnessVolumeOverlay = false;
    setState(() {
      _isSeeking = true;
    });
  }

  void _hideSeekOverlay() {
    setState(() {
      _isSeeking = false;
    });
  }

  void _handleDoubleTap(TapDownDetails details) {
    final tapX = details.globalPosition.dx;
    final screenWidth = MediaQuery.of(context).size.width;

    if (tapX < screenWidth / 4) {
      _onDoubleTapLeft();
    } else if (tapX > 3 * screenWidth / 4) {
      _onDoubleTapRight();
    }
  }

  void _onDoubleTapLeft() {
    _leftDoubleTapCount++;
    _resetDoubleTapCountTimer?.cancel();
    _resetDoubleTapCountTimer =
        Timer(const Duration(seconds: 1), _resetDoubleTapCounts);

    _showDoubleTapIcon(isLeft: true);
    _skipBack();
  }

  void _onDoubleTapRight() {
    _rightDoubleTapCount++;
    _resetDoubleTapCountTimer?.cancel();
    _resetDoubleTapCountTimer =
        Timer(const Duration(seconds: 1), _resetDoubleTapCounts);

    _showDoubleTapIcon(isLeft: false);
    _skipForward();
  }

  void _showDoubleTapIcon({required bool isLeft}) {
    setState(() {
      if (isLeft) {
        _showLeftDoubleTapIcon = true;
      } else {
        _showRightDoubleTapIcon = true;
      }
    });

    _doubleTapIconHideTimer?.cancel();
    _doubleTapIconHideTimer = Timer(const Duration(milliseconds: 600), () {
      setState(() {
        _showLeftDoubleTapIcon = false;
        _showRightDoubleTapIcon = false;
      });
    });
  }

  void _skipBack() {
    if (_controller != null) {
      final currentPosition = _controller!.value.position;
      final skipDuration = Duration(seconds: _leftDoubleTapCount * 10);
      final newPosition = currentPosition - skipDuration;
      _controller!.seekTo(newPosition);
    }
  }

  void _skipForward() {
    if (_controller != null) {
      final currentPosition = _controller!.value.position;
      final skipDuration = Duration(seconds: _rightDoubleTapCount * 10);
      final newPosition = currentPosition + skipDuration;
      _controller!.seekTo(newPosition);
    }
  }

  void _resetDoubleTapCounts() {
    _leftDoubleTapCount = 0;
    _rightDoubleTapCount = 0;
  }

  Widget _buildLeftDoubleTapIcon() {
    return Positioned(
      left: 50,
      top: _betterPlayerController!.isFullScreen ? MediaQuery.of(context).size.height / 2 - 50 : 60,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedOpacity(
          opacity: _showLeftDoubleTapIcon ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              Icon(
                Icons.keyboard_double_arrow_left,
                color: Colors.white,
                size: 50,
              ),
              Text("${_leftDoubleTapCount * 10} Seconds"),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightDoubleTapIcon() {
    return Positioned(
      right: 50,
      top: _betterPlayerController!.isFullScreen ? MediaQuery.of(context).size.height / 2 - 50 : 60,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedOpacity(
          opacity: _showRightDoubleTapIcon ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              Icon(
                Icons.keyboard_double_arrow_right,
                color: Colors.white,
                size: 50,
              ),
              Text("${_rightDoubleTapCount * 10} Seconds"),

            ],
          ),
        ),
      ),
    );
  }

  void _adjustBrightness(double delta) async {
    _brightness = (_brightness + delta).clamp(0.0, 1.0);
    await ScreenBrightness().setScreenBrightness(_brightness);
    _showOverlay("Brightness: ${(_brightness * 100).round()}%");
  }

  void _adjustVolume(double delta) {
    _volume = (_volume + delta).clamp(0.0, 1.0);
    VolumeController().setVolume(_volume);
    _showOverlay("Volume: ${(_volume * 100).round()}%");
  }

  Widget _buildBrightnessVolumeOverlay() {
    final isBrightness = _overlayText.contains('Brightness');
    final overlayIcon = isBrightness ? Icons.wb_sunny : Icons.volume_up;
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.4,
      left: MediaQuery.of(context).size.width * 0.3,
      right: MediaQuery.of(context).size.width * 0.3,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              overlayIcon,
              color: Colors.white,
              size: 40,
            ),
            Text(
              _overlayText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _overlayText.contains('Brightness') ? _brightness : _volume,
              backgroundColor: Colors.grey,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              // valueColor: AlwaysStoppedAnimation<Color>(
              //   _overlayText.contains('Brightness')
              //       ? Colors.yellow.shade600
              //       : Colors.blue.shade600,
              // ),
              minHeight: 8.0, // Increase the height for better visibility
              semanticsLabel: _overlayText,
              semanticsValue: "${(_brightness * 100).round()}%", // Display value as percentage
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showOverlay(String text) {
    setState(() {
      _overlayText = text;
      _showBrightnessVolumeOverlay = true;
    });

    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(seconds: 1), () {
      setState(() {
        _showBrightnessVolumeOverlay = false;
      });
    });
  }

  Widget _buildSeekOverlay() {
    final videoDuration = _controller?.value.duration ?? Duration.zero;
    final currentPosition = _controller?.value.position ?? Duration.zero;
    final seekedTime = _seekPosition - currentPosition;

    return _betterPlayerController!.isFullScreen ? Positioned(
      top: MediaQuery.of(context).size.height * 0.4,
      left: MediaQuery.of(context).size.width * 0.3,
      right: MediaQuery.of(context).size.width * 0.3,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${_formatDuration(_seekPosition)} / ${_formatDuration(videoDuration)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              seekedTime.isNegative
                  ? "[ -${_formatDuration(seekedTime.abs())} ]"
                  : "[ +${_formatDuration(seekedTime)} ]",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _controller != null && videoDuration != Duration.zero
                  ? _seekPosition.inMilliseconds / videoDuration.inMilliseconds
                  : 0.0,
              backgroundColor: Colors.grey,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8.0,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    ) : Positioned(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${_formatDuration(_seekPosition)} / ${_formatDuration(videoDuration)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              seekedTime.isNegative
                  ? "[ -${_formatDuration(seekedTime.abs())} ]"
                  : "[ +${_formatDuration(seekedTime)} ]",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }


  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();

    _overlayHideTimer?.cancel();
    _doubleTapIconHideTimer?.cancel();
    _resetDoubleTapCountTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu)
          ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.0),
                    ],
                  ),
                ),
                height: _controlsConfiguration.controlBarHeight +
                    (_betterPlayerController!.isFullScreen ? 20 : 0),
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildBackButton(),
                    Expanded(
                      // padding: const EdgeInsets.all(8),
                      // width: MediaQuery.of(context).size.width /
                      //     (betterPlayerController!.isFullScreen ? 1.4 : 2.2),
                      child: Text(
                        _betterPlayerController?.betterPlayerDataSource?.url
                                .split('/')
                                .last ??
                            "Unknown",
                        maxLines: betterPlayerController!.isFullScreen ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    // const Spacer(),
                    if (_controlsConfiguration.enablePip)
                      _buildPipButtonWrapperWidget(
                          controlsNotVisible, _onPlayerHide)
                    else
                      _buildAudioButton(),
                    _buildSpeedButton(),
                    _buildSubtitleButton(),
                    _buildMoreButton(),
                  ],
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          betterPlayerControlsConfiguration.pipMenuIcon,
          size: 24,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    return FutureBuilder<bool>(
      future: betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return AnimatedOpacity(
            opacity: hideStuff ? 0.0 : 1.0,
            duration: betterPlayerControlsConfiguration.controlsHideTime,
            onEnd: onPlayerHide,
            child: Container(
              height: betterPlayerControlsConfiguration.controlBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPipButton(),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMoreButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _controlsConfiguration.overflowMenuIcon,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildSubtitleButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowSubtitlesClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.subtitles_outlined,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildAudioButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowAudioTracksClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.audiotrack_outlined,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildSpeedButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowSpeedClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.speed,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        onEnd: _onPlayerHide,
        child: _buildLockButton(),
      );
    }
    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.5),
              Colors.black.withOpacity(0.4),
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.2),
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.0),
            ],
          ),
        ),
        height: _controlsConfiguration.controlBarHeight +
            (_betterPlayerController!.isFullScreen ? 20 : 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisAlignment: _betterPlayerController!.isLiveStream()
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.spaceEvenly,
              children: [
                if (_betterPlayerController!.isLiveStream()) ...[
                  _buildLiveWidget(),
                ] else ...[
                  if (_controlsConfiguration.enableProgressText)
                    _buildPosition()
                  else
                    const SizedBox(),
                  if (_controlsConfiguration.enableProgressBar)
                    _buildProgressBar()
                  else
                    const SizedBox(),
                  if (_controlsConfiguration.enableProgressText)
                    _buildDuration()
                  else
                    const SizedBox(),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Expanded(
              flex: 75,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLockButton(),
                  _buildLoopButton(_controller),
                  const Spacer(),
                  if (_controlsConfiguration.enablePlayPause) ...[
                    _buildPreviousButton(),
                    const SizedBox(
                      width: 12,
                    ),
                    _buildPlayPause(_controller!),
                    const SizedBox(
                      width: 12,
                    ),
                    _buildNextButton(),
                  ] else
                    const SizedBox(),
                  const Spacer(),
                  if (_controlsConfiguration.enableMute)
                    _buildMuteButton(_controller)
                  else
                    const SizedBox(),
                  if (_controlsConfiguration.enableFullscreen)
                    _buildExpandButton()
                  else
                    const SizedBox(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Text(
        _betterPlayerController!.translations.controlsLive,
        style: TextStyle(
            color: _controlsConfiguration.liveTextColor,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildExpandButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: _onExpandCollapse,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          _betterPlayerController!.isFullScreen
              ? _controlsConfiguration.fullscreenDisableIcon
              : _controlsConfiguration.fullscreenEnableIcon,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Center(
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: _buildMiddleRow(),
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Container(
      color: Colors.transparent,
      width: double.infinity,
      height: double.infinity,
      child: _betterPlayerController?.isLiveStream() == true
          ? const SizedBox()
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_controlsConfiguration.enableSkips)
            Expanded(child: _buildSkipButton())
          else
            const SizedBox(),
          _buildReplayButton(_controller!),
          if (_controlsConfiguration.enableSkips)
            Expanded(child: _buildForwardButton())
          else
            const SizedBox(),
        ],
      ),
    );
  }

  Widget _buildHitAreaClickableButton(
      {Widget? icon, required void Function() onClicked}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon!],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipBackIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipBack,
    );
  }

  Widget _buildForwardButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipForwardIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipForward,
    );
  }

  Widget _buildReplayButton(VideoPlayerController controller) {
    final bool isFinished = isVideoFinished(_latestValue);
    return isFinished
        ? _buildHitAreaClickableButton(
            icon: Icon(
              Icons.replay,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            ),
            onClicked: () {
              if (isFinished) {
                if (_latestValue != null && _latestValue!.isPlaying) {
                  if (_displayTapped) {
                    changePlayerControlsNotVisible(true);
                  } else {
                    cancelAndRestartTimer();
                  }
                } else {
                  _onPlayPause();
                  changePlayerControlsNotVisible(true);
                }
              } else {
                // _onPlayPause();
              }
            },
          )
        : const SizedBox();
  }

  // Widget _buildReplayButton(VideoPlayerController controller) {
  //   final bool isFinished = isVideoFinished(_latestValue);
  //   return _buildHitAreaClickableButton(
  //     icon: isFinished
  //         ? Icon(
  //       Icons.replay,
  //       size: 42,
  //       color: _controlsConfiguration.iconsColor,
  //     )
  //         : Icon(
  //       controller.value.isPlaying
  //           ? _controlsConfiguration.pauseIcon
  //           : _controlsConfiguration.playIcon,
  //       size: 42,
  //       color: _controlsConfiguration.iconsColor,
  //     ),
  //     onClicked: () {
  //       if (isFinished) {
  //         if (_latestValue != null && _latestValue!.isPlaying) {
  //           if (_displayTapped) {
  //             changePlayerControlsNotVisible(true);
  //           } else {
  //             cancelAndRestartTimer();
  //           }
  //         } else {
  //           _onPlayPause();
  //           changePlayerControlsNotVisible(true);
  //         }
  //       } else {
  //         _onPlayPause();
  //       }
  //     },
  //   );
  // }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return BetterPlayerMaterialClickableWidget(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: EdgeInsets.only(
                    bottom: _controlsConfiguration.controlBarHeight + 20,
                    right: 24),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMuteButton(
    VideoPlayerController? controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        if (_latestValue!.volume == 0) {
          _betterPlayerController!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          _betterPlayerController!.setVolume(0.0);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          (_latestValue != null && _latestValue!.volume > 0)
              ? _controlsConfiguration.muteIcon
              : _controlsConfiguration.unMuteIcon,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildLoopButton(
    VideoPlayerController? controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        if(_isLooping){
          _betterPlayerController?.setLooping(false);
        }else{
          _betterPlayerController?.setLooping(true);
        }

        _isLooping = !_isLooping; // Toggle looping status

        // if (_betterPlayerController?.getFit() == BoxFit.cover) {
        //   _betterPlayerController?.setOverriddenFit(BoxFit.contain);
        // } else {
        //   _betterPlayerController?.setOverriddenFit(BoxFit.cover);
        // }
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          _isLooping
              ? Icons.repeat_one
              : Icons.repeat,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_play_pause_button"),
      onTap: _onPlayPause,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          size: 32,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildLockButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        if (_betterPlayerController!.controlsEnabled) {
          _betterPlayerController?.setControlsEnabled(false);
        } else {
          _betterPlayerController?.setControlsEnabled(true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          _betterPlayerController!.controlsEnabled
              ? Icons.lock_open
              : Icons.lock_outline,
          size: 25,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        _betterPlayerController!.playNextVideo();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          Icons.skip_next,
          size: 26,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPreviousButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        _betterPlayerController!.playPreviousVideo();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          Icons.skip_previous,
          size: 26,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        BetterPlayerUtils.formatDuration(position),
        style: TextStyle(
          fontSize: 12.0,
          color: _controlsConfiguration.textColor,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildDuration() {
    final duration = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration!
        : Duration.zero;

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          BetterPlayerUtils.formatDuration(duration),
          style: TextStyle(
            fontSize: 12.0,
            color: _controlsConfiguration.textColor,
            decoration: TextDecoration.none,
          ),
        ));
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _showAfterExpandCollapseTimer =
        Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) &&
              _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      flex: 1,
      child: Container(
        height: 20,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: BetterPlayerMaterialVideoProgressBar(
          _controller,
          _betterPlayerController,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          onTapDown: () {
            cancelAndRestartTimer();
          },
          colors: BetterPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }
}
