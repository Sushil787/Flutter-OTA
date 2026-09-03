import 'package:flutter/foundation.dart';

/// Where an update check has got to.
enum FlutroidStage {
  /// Nothing has run yet this session.
  idle,

  /// Asking the server whether a newer patch exists.
  checking,

  /// Pulling the patch down; [FlutroidProgress.fraction] tracks it.
  downloading,

  /// Verifying the bytes and handing them to the native side.
  staging,

  /// The server had nothing newer.
  upToDate,

  /// A patch is on disk and loads at the next launch.
  staged,

  /// The check did not finish; [FlutroidProgress.error] says why.
  failed,
}

/// Where the updater has got to, for showing in the UI.
///
/// `Flutroid.progress` exposes this as a [ValueListenable], so a widget can
/// rebuild on it without the app tracking anything itself.
@immutable
class FlutroidProgress {
  const FlutroidProgress({
    this.stage = FlutroidStage.idle,
    this.received = 0,
    this.total = 0,
    this.patchNumber,
    this.error,
  });

  final FlutroidStage stage;

  /// Bytes downloaded so far.
  final int received;

  /// Total bytes to download, or 0 when the server sent no content-length.
  final int total;

  /// The patch being downloaded, or the one that was staged.
  final int? patchNumber;

  /// Why the check failed, when [stage] is [FlutroidStage.failed].
  final String? error;

  /// How far along the download is, 0 to 1, or null when the size is unknown.
  /// Null is the cue for a spinner rather than a bar stuck at zero.
  double? get fraction =>
      total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  /// Whether something is happening right now.
  bool get isBusy =>
      stage == FlutroidStage.checking ||
      stage == FlutroidStage.downloading ||
      stage == FlutroidStage.staging;

  /// A ready-made line to show next to the bar.
  String get label => switch (stage) {
    FlutroidStage.idle => 'Idle',
    FlutroidStage.checking => 'Checking for updates…',
    FlutroidStage.downloading => patchNumber == null
        ? 'Downloading…'
        : 'Downloading patch $patchNumber…',
    FlutroidStage.staging => 'Installing…',
    FlutroidStage.upToDate => 'Up to date',
    FlutroidStage.staged => 'Patch $patchNumber ready — restart to apply',
    FlutroidStage.failed => error ?? 'Update failed',
  };

  FlutroidProgress copyWith({
    FlutroidStage? stage,
    int? received,
    int? total,
    int? patchNumber,
    String? error,
  }) => FlutroidProgress(
    stage: stage ?? this.stage,
    received: received ?? this.received,
    total: total ?? this.total,
    patchNumber: patchNumber ?? this.patchNumber,
    error: error ?? this.error,
  );

  @override
  String toString() =>
      'FlutroidProgress(${stage.name}, $received/$total, patch: $patchNumber)';
}
