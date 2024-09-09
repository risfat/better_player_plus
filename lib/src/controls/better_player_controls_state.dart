import 'dart:io';
import 'dart:math';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/controls/better_player_clickable_widget.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:better_player_plus/src/core/subtitle_downloader.dart';
import 'package:better_player_plus/src/core/language_list.dart';

///Base class for both material and cupertino controls
abstract class BetterPlayerControlsState<T extends StatefulWidget>
    extends State<T> {
  ///Min. time of buffered video to hide loading timer (in milliseconds)
  static const int _bufferingInterval = 20000;

  BetterPlayerController? get betterPlayerController;

  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration;

  VideoPlayerValue? get latestValue;

  bool controlsNotVisible = true;

  void cancelAndRestartTimer();

  bool isVideoFinished(VideoPlayerValue? videoPlayerValue) {
    return videoPlayerValue?.position != null &&
        videoPlayerValue?.duration != null &&
        videoPlayerValue!.position.inMilliseconds != 0 &&
        videoPlayerValue.duration!.inMilliseconds != 0 &&
        videoPlayerValue.position >= videoPlayerValue.duration!;
  }

  void skipBack() {
    if (latestValue != null) {
      cancelAndRestartTimer();
      final beginning = const Duration().inMilliseconds;
      final skip = (latestValue!.position -
              Duration(
                  milliseconds: betterPlayerControlsConfiguration
                      .backwardSkipTimeInMilliseconds))
          .inMilliseconds;
      betterPlayerController!
          .seekTo(Duration(milliseconds: max(skip, beginning)));
    }
  }

  void skipForward() {
    if (latestValue != null) {
      cancelAndRestartTimer();
      final end = latestValue!.duration!.inMilliseconds;
      final skip = (latestValue!.position +
              Duration(
                  milliseconds: betterPlayerControlsConfiguration
                      .forwardSkipTimeInMilliseconds))
          .inMilliseconds;
      betterPlayerController!.seekTo(Duration(milliseconds: min(skip, end)));
    }
  }

  void onShowMoreClicked() {
    _showModalBottomSheet([_buildMoreOptionsList()]);
  }

  void onShowSubtitlesClicked(){
    _showSubtitlesSelectionWidget();
  }

  void onShowAudioTracksClicked(){
    _showAudioTracksSelectionWidget();
  }

  void onShowSpeedClicked(){
    _showSpeedChooserWidget();
  }

  Widget _buildMoreOptionsList() {
    final translations = betterPlayerController!.translations;
    return SingleChildScrollView(
      // ignore: avoid_unnecessary_containers
      child: Container(
        child: Column(
          children: [
            if (betterPlayerControlsConfiguration.enablePlaybackSpeed)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.playbackSpeedIcon,
                  translations.overflowMenuPlaybackSpeed, () {
                Navigator.of(context).pop();
                _showSpeedChooserWidget();
              }),
            if (betterPlayerControlsConfiguration.enableSubtitles)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.subtitlesIcon,
                  translations.overflowMenuSubtitles, () {
                Navigator.of(context).pop();
                _showSubtitlesSelectionWidget();
              }),
            if (betterPlayerControlsConfiguration.enableQualities)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.qualitiesIcon,
                  translations.overflowMenuQuality, () {
                Navigator.of(context).pop();
                _showQualitiesSelectionWidget();
              }),
            if (betterPlayerControlsConfiguration.enableAudioTracks)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.audioTracksIcon,
                  translations.overflowMenuAudioTracks, () {
                Navigator.of(context).pop();
                _showAudioTracksSelectionWidget();
              }),
            _buildMoreOptionsListRow(
                Icons.fit_screen,
                "Aspect Ratio & Fit", () {
              Navigator.of(context).pop();
              _showFitChooserWidget();
            }),
            if (betterPlayerControlsConfiguration
                .overflowMenuCustomItems.isNotEmpty)
              ...betterPlayerControlsConfiguration.overflowMenuCustomItems.map(
                (customItem) => _buildMoreOptionsListRow(
                  customItem.icon,
                  customItem.title,
                  () {
                    Navigator.of(context).pop();
                    customItem.onClicked.call();
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsListRow(
      IconData icon, String name, void Function() onTap) {
    return BetterPlayerMaterialClickableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              icon,
              color: betterPlayerControlsConfiguration.overflowMenuIconsColor,
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(false),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedChooserWidget() {
    _showModalBottomSheet([
      _buildSpeedRow(0.25),
      _buildSpeedRow(0.5),
      _buildSpeedRow(0.75),
      _buildSpeedRow(1.0),
      _buildSpeedRow(1.25),
      _buildSpeedRow(1.5),
      _buildSpeedRow(1.75),
      _buildSpeedRow(2.0),
    ]);
  }

  void _showFitChooserWidget() {
    _showModalBottomSheet([
      _buildFitRow(BoxFit.fill),
      _buildFitRow(BoxFit.contain),
      _buildFitRow(BoxFit.cover),
      _buildFitRow(BoxFit.fitWidth),
      _buildFitRow(BoxFit.fitHeight),
      _buildFitRow(BoxFit.scaleDown),
      _buildFitRow(BoxFit.none)
    ]);
  }

  Widget _buildSpeedRow(double value) {
    final bool isSelected =
        betterPlayerController!.videoPlayerController!.value.speed == value;

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setSpeed(value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                      betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              "$value x",
              style: _getOverflowMenuElementTextStyle(isSelected),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFitRow(BoxFit fit) {
    final bool isSelected =
        betterPlayerController?.getFit() == fit;

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController?.setOverriddenFit(fit);
        betterPlayerController?.postEvent(
            BetterPlayerEvent(BetterPlayerEventType.changedFit));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                  betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              fit.name[0].toUpperCase() + fit.name.substring(1),
              style: _getOverflowMenuElementTextStyle(isSelected),
            )
          ],
        ),
      ),
    );
  }

  ///Latest value can be null
  bool isLoading(VideoPlayerValue? latestValue) {
    if (latestValue != null) {
      if (!latestValue.isPlaying && latestValue.duration == null) {
        return true;
      }

      final Duration position = latestValue.position;

      Duration? bufferedEndPosition;
      if (latestValue.buffered.isNotEmpty == true) {
        bufferedEndPosition = latestValue.buffered.last.end;
      }

      if (bufferedEndPosition != null) {
        final difference = bufferedEndPosition - position;

        if (latestValue.isPlaying &&
            latestValue.isBuffering &&
            difference.inMilliseconds < _bufferingInterval) {
          return true;
        }
      }
    }
    return false;
  }

// Store the path of the selected local subtitle file
  String? _selectedLocalSubtitlePath;

  Future<void> _pickLocalSubtitle() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      BetterPlayerSubtitlesSource localSubtitleSource = BetterPlayerSubtitlesSource(
        type: BetterPlayerSubtitlesSourceType.file,
        urls: [file.path],
        name: "Local Subtitle",
      );

      await betterPlayerController!.setupSubtitleSource(localSubtitleSource);

      // Store the selected subtitle file path
      _selectedLocalSubtitlePath = file.path;

      Navigator.of(context).pop();
    }
  }

  void _showSubtitleSearchWidget() {
    final videoFileName = path.basenameWithoutExtension(
        betterPlayerController!.betterPlayerDataSource?.url ?? '');
    final TextEditingController _searchQueryController =
    TextEditingController(text: videoFileName);
    String _selectedLanguage = 'en';
    String _selectedOrderBy = 'new_download_count';
    bool _useHash = false; // Default value for Use Hash

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          scrollable: true,
          title: Center(
            child: Text('Search Subtitles'),
          ),
          titleTextStyle: TextStyle(fontSize: 20),
          titlePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          actionsPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchQueryController,
                      decoration: InputDecoration(
                        labelText: 'Search Query',
                        hintText: 'Enter movie/series name',
                      ),
                    ),
                    SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      style: TextStyle(fontWeight: FontWeight.normal),
                      dropdownColor: Colors.black,
                      decoration: InputDecoration(
                        labelText: 'Language',
                        fillColor: Colors.black.withOpacity(0.8),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      items: getLanguageDropdownItems(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value!;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedOrderBy,
                      dropdownColor: Colors.black,
                      style: TextStyle(fontWeight: FontWeight.normal),
                      decoration: InputDecoration(
                        labelText: 'Order By',
                        fillColor: Colors.black.withOpacity(0.8),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'new_download_count',
                            child: Text('Most Popular')),
                        DropdownMenuItem(
                            value: 'download_count', child: Text('Most Downloaded')),
                        DropdownMenuItem(value: 'ratings', child: Text('Best Rated')),
                        DropdownMenuItem(value: 'points', child: Text('Most Points')),
                        DropdownMenuItem(value: 'votes', child: Text('Most Votes')),
                        DropdownMenuItem(
                            value: 'upload_date', child: Text('Upload Date')),
                        DropdownMenuItem(
                            value: 'from_trusted', child: Text('From Trusted')),
                        DropdownMenuItem(
                            value: 'ai_translated',
                            child: Text('Ai Translated')),
                        DropdownMenuItem(
                            value: 'hearing_impaired',
                            child: Text('Hearing Impaired')),
                        DropdownMenuItem(
                            value: 'foreign_parts_only',
                            child: Text('Foreign Parts Only')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedOrderBy = value!;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Use Hash',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Yes',style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
                            value: true,
                            groupValue: _useHash,
                            onChanged: (value) {
                              setState(() {
                                _useHash = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
                            value: false,
                            groupValue: _useHash,
                            onChanged: (value) {
                              setState(() {
                                _useHash = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _searchAndDownloadSubtitle(
                  _searchQueryController.text,
                  _selectedLanguage,
                  _selectedOrderBy,
                  _useHash,
                );
              },
              child: Text('Search'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchAndDownloadSubtitle(
      String query, String language, String orderBy, bool useHash) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    final _subtitleDownloader = SubtitleDownloader();
    try {
      final videoPath = betterPlayerController!.betterPlayerDataSource?.url;
      if (videoPath != null) {
        // Search for subtitles using the SubtitleDownloader
        final subtitles = await _subtitleDownloader.searchSubtitles(
          videoPath,
          language: language,
          orderBy: orderBy,
          useHash: useHash,
        );

        // Close the loading dialog
        Navigator.of(context).pop();

        if (subtitles != null && subtitles.isNotEmpty) {
          // Show the list of available subtitles to the user
          _showSubtitleSelectionDialog(subtitles);
        } else {
          // Handle the error (no subtitles found)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No subtitles found for the given query.')),
          );
        }
      } else {
        // Close the loading dialog
        Navigator.of(context).pop();

        // Handle the error (video file is null)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No video file found to search subtitles.')),
        );
      }
    } catch (e) {
      // Close the loading dialog
      Navigator.of(context).pop();

      // Handle the error (exception occurred)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching subtitles: $e')),
      );
    }
  }

  void _showSubtitleSelectionDialog(List<Map<String, dynamic>> subtitles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // Rounded corners for dialog
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Subtitle',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height/2, // Adjust height as needed
                child: ListView.builder(
                  itemCount: subtitles.length,
                  itemBuilder: (context, index) {
                    final subtitle = subtitles[index];
                    final attributes = subtitle['attributes'];
                    final fileName = attributes['release'] ?? 'Unknown';
                    final language = attributes['language'] ?? 'Unknown';
                    final downloads = attributes['download_count'] ?? 'Unknown';

                    return Card(
                      color: Colors.grey.withOpacity(0.15),
                      margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 10),
                      elevation: 2.0,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        leading: CircleAvatar(
                          radius: 20.0,
                          backgroundColor: Colors.blueGrey[100],
                          child: Icon(Icons.subtitles, size: 20.0, color: Colors.blueGrey[700]),
                        ),
                        title: Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Language: ${language.toUpperCase()} | Downloads: $downloads',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.grey[600],
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop(); // Close the dialog
                          final fileId = attributes['files'].first['file_id'];
                          await _downloadAndApplySubtitle(fileId);
                        },
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0)),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel'
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _downloadAndApplySubtitle(int fileId) async {

    final _subtitleDownloader = SubtitleDownloader();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    final subtitleFilePath = await getSubtitleFilePath(betterPlayerController?.betterPlayerDataSource!.url);

    try {
      final subtitlesFile = await _subtitleDownloader.downloadSubtitles(
          fileId,
          subtitleFilePath!
      );

      if (subtitlesFile != null) {
        // Apply the downloaded subtitle file to the video player
        BetterPlayerSubtitlesSource subtitleSource =
        BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.file,
          urls: [subtitlesFile.path],
          name: "Downloaded Subtitle",
        );

        await betterPlayerController!.setupSubtitleSource(subtitleSource);


        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subtitle downloaded and applied successfully!')),
        );
      } else {

        // Handle subtitle download failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download subtitle.')),
        );
      }
    }catch(e) {
      // Handle subtitle download failure
      if (e is PathAccessException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download subtitle. To download subtitle you have to allow Manage Storage permission.')),
        );
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download subtitle. Error: ${e.toString()}')),
        );
      }
    }finally{
      // Close the loading dialog
      Navigator.of(context).pop();
    }
  }

  Future<String?> getSubtitleFilePath(String? videoFilePath) async{
    // Check if the input video file path is null
    if (videoFilePath == null || videoFilePath.isEmpty) {
      return null; // Return null if the video file path is invalid
    }
    //
    // // Create a File object for the video
    // final video = File(videoFilePath);

    // Get the directory where the video file is located
    // final subtitlesDir = video.parent;

    final subtitlesDir = await getOrCreateSubtitlesDirectory();

    // Extract the base file name (without extension) of the video
    final baseFileName = path.basenameWithoutExtension(videoFilePath);

    // Construct the subtitle file path by appending ".srt" to the base file name
    final subtitleFilePath = path.join(subtitlesDir.path, "$baseFileName.srt");

    // Return the constructed subtitle file path
    return subtitleFilePath;
  }

  Future<Directory> getOrCreateSubtitlesDirectory() async {
    // Get the directory for the application's documents
    final Directory appDocDir = await getApplicationDocumentsDirectory();

    // Define the path for the "Subtitles" directory within the application's documents directory
    final Directory subtitlesDir = Directory('${appDocDir.path}/Subtitles');

    print(
        "====================Subtitles Dir: ${subtitlesDir.path} (better_player)===============================");
    // Check if the directory exists
    if (await subtitlesDir.exists()) {
      // If it exists, return the directory
      return subtitlesDir;
    } else {
      // If it doesn't exist, create the directory and return it
      return await subtitlesDir.create(recursive: true);
    }
  }



  void _showSubtitlesSelectionWidget() {
    final subtitles =
        List.of(betterPlayerController!.betterPlayerSubtitlesSourceList);
    // final noneSubtitlesElementExists = subtitles.firstWhereOrNull(
    //         (source) => source.type == BetterPlayerSubtitlesSourceType.none) !=
    //     null;
    // if (!noneSubtitlesElementExists) {
    //   subtitles.add(BetterPlayerSubtitlesSource(
    //       type: BetterPlayerSubtitlesSourceType.none));
    // }

    final localSubtitlesElement = [
      BetterPlayerMaterialClickableWidget(
        onTap: (){
          Navigator.of(context).pop();
          _showSubtitleSearchWidget();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Text(
                "Search from Online",
                style: _getOverflowMenuElementTextStyle( false),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.online_prediction,
                color:
                betterPlayerControlsConfiguration.overflowModalTextColor,
              )
            ],
          ),
        ),
      ),
      BetterPlayerMaterialClickableWidget(
      onTap: _pickLocalSubtitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 32),
            Text(
              "Select from Local Storage",
              style: _getOverflowMenuElementTextStyle( _selectedLocalSubtitlePath != null ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.storage,
              color:
              betterPlayerControlsConfiguration.overflowModalTextColor,
            )
          ],
        ),
      ),
    )];
    _showModalBottomSheet(
        subtitles.map((source) => _buildSubtitlesSourceRow(source)).toList()..addAll(localSubtitlesElement));
  }

  Widget _buildSubtitlesSourceRow(BetterPlayerSubtitlesSource subtitlesSource) {
    final selectedSource = betterPlayerController!.betterPlayerSubtitlesSource;
    final bool isSelected = (subtitlesSource == selectedSource) ||
        (subtitlesSource.type == BetterPlayerSubtitlesSourceType.none &&
            subtitlesSource.type == selectedSource!.type);

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setupSubtitleSource(subtitlesSource);
        _selectedLocalSubtitlePath = null;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                  betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              subtitlesSource.type == BetterPlayerSubtitlesSourceType.none
                  ? betterPlayerController!.translations.generalNone
                  : subtitlesSource.name ??
                  betterPlayerController!.translations.generalDefault,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }
  ///Build both track and resolution selection
  ///Track selection is used for HLS / DASH videos
  ///Resolution selection is used for normal videos
  void _showQualitiesSelectionWidget() {
    // HLS / DASH
    final List<String> asmsTrackNames =
        betterPlayerController!.betterPlayerDataSource!.asmsTrackNames ?? [];
    final List<BetterPlayerAsmsTrack> asmsTracks =
        betterPlayerController!.betterPlayerAsmsTracks;
    final List<Widget> children = [];
    for (var index = 0; index < asmsTracks.length; index++) {
      final track = asmsTracks[index];

      String? preferredName;
      if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
        preferredName = betterPlayerController!.translations.qualityAuto;
      } else {
        preferredName =
            asmsTrackNames.length > index ? asmsTrackNames[index] : null;
      }
      children.add(_buildTrackRow(asmsTracks[index], preferredName));
    }

    // normal videos
    final resolutions =
        betterPlayerController!.betterPlayerDataSource!.resolutions;
    resolutions?.forEach((key, value) {
      children.add(_buildResolutionSelectionRow(key, value));
    });

    if (children.isEmpty) {
      children.add(
        _buildTrackRow(BetterPlayerAsmsTrack.defaultTrack(),
            betterPlayerController!.translations.qualityAuto),
      );
    }

    _showModalBottomSheet(children);
  }

  Widget _buildTrackRow(BetterPlayerAsmsTrack track, String? preferredName) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;
    final int bitrate = track.bitrate ?? 0;
    final String mimeType = (track.mimeType ?? '').replaceAll('video/', '');
    final String trackName = preferredName ??
        "${width}x$height ${BetterPlayerUtils.formatBitrate(bitrate)} $mimeType";

    final BetterPlayerAsmsTrack? selectedTrack =
        betterPlayerController!.betterPlayerAsmsTrack;
    final bool isSelected = selectedTrack != null && selectedTrack == track;

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setTrack(track);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                      betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              trackName,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionSelectionRow(String name, String url) {
    final bool isSelected =
        url == betterPlayerController!.betterPlayerDataSource!.url;
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setResolution(url);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                      betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioTracksSelectionWidget() {
    //HLS / DASH
    final List<BetterPlayerAsmsAudioTrack>? asmsTracks =
        betterPlayerController!.betterPlayerAsmsAudioTracks;
    final List<Widget> children = [];
    final BetterPlayerAsmsAudioTrack? selectedAsmsAudioTrack =
        betterPlayerController!.betterPlayerAsmsAudioTrack;
    if (asmsTracks != null) {
      for (var index = 0; index < asmsTracks.length; index++) {
        final bool isSelected = selectedAsmsAudioTrack != null &&
            selectedAsmsAudioTrack == asmsTracks[index];
        children.add(_buildAudioTrackRow(asmsTracks[index], isSelected));
      }
    }

    if (children.isEmpty) {
      children.add(
        _buildAudioTrackRow(
          BetterPlayerAsmsAudioTrack(
            label: betterPlayerController!.translations.generalDefault,
          ),
          true,
        ),
      );
    }

    _showModalBottomSheet(children);
  }

  Widget _buildAudioTrackRow(
      BetterPlayerAsmsAudioTrack audioTrack, bool isSelected) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setAudioTrack(audioTrack);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                      betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              audioTrack.label!,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _getOverflowMenuElementTextStyle(bool isSelected) {
    return TextStyle(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected
          ? betterPlayerControlsConfiguration.overflowModalTextColor
          : betterPlayerControlsConfiguration.overflowModalTextColor
              .withOpacity(0.7),
    );
  }

  void _showModalBottomSheet(List<Widget> children) {
    Platform.isAndroid
        ? _showMaterialBottomSheet(children)
        : _showCupertinoModalBottomSheet(children);
  }

  void _showCupertinoModalBottomSheet(List<Widget> children) {
    showCupertinoModalPopup<void>(
      barrierColor: Colors.transparent,
      context: context,
      useRootNavigator:
          betterPlayerController?.betterPlayerConfiguration.useRootNavigator ??
              false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: betterPlayerControlsConfiguration.overflowModalColor,
                /*shape: RoundedRectangleBorder(side: Bor,borderRadius: 24,)*/
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0)),
              ),
              child: Column(
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMaterialBottomSheet(List<Widget> children) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.transparent,
      context: context,
      useRootNavigator:
          betterPlayerController?.betterPlayerConfiguration.useRootNavigator ??
              false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: betterPlayerControlsConfiguration.overflowModalColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0)),
              ),
              child: Column(
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  ///Builds directionality widget which wraps child widget and forces left to
  ///right directionality.
  Widget buildLTRDirectionality(Widget child) {
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  ///Called when player controls visibility should be changed.
  void changePlayerControlsNotVisible(bool notVisible) {
    setState(() {
      if (notVisible) {
        betterPlayerController?.postEvent(
            BetterPlayerEvent(BetterPlayerEventType.controlsHiddenStart));
      }
      controlsNotVisible = notVisible;
    });
  }
}
