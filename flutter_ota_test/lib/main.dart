import 'package:flutter_ota_package/flutter_ota_package.dart';
import 'package:flutter/material.dart';

/// Change this, rebuild, and ship it with `flutter_ota patch`. Seeing the new text
/// after a cold start means the downloaded code is what ran.
const String kBuildMarker = '12:47 k xa baby ';

/// Where the backend is reachable from the device. Use `10.0.2.2` on the
/// Android emulator, or your machine's LAN address on a real phone.
const String kUpdateUrl = 'http://192.168.1.64:8080';

Future<void> main() async {
  // Checks for a patch in the background and stages it. Nothing to call by
  // hand: the app bar shows the progress.
  await FlutterOta.initialize(updateUrl: kUpdateUrl);
  runApp(const FlutterOtaDemo());
}

class FlutterOtaDemo extends StatelessWidget {
  const FlutterOtaDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter OTA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Rebuilds whenever the updater moves on, so the bar and the card below
    // both stay current.
    return ValueListenableBuilder<FlutterOtaProgress>(
      valueListenable: FlutterOta.instance.progress,
      builder: (context, update, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Flutter OTA'),
          bottom: _UpdateBar.of(update),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(kBuildMarker, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  FlutterOta.instance.releaseVersion,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                _StateCard(state: FlutterOta.instance.state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The progress strip under the app bar.
class _UpdateBar extends StatelessWidget implements PreferredSizeWidget {
  const _UpdateBar({required this.update});

  /// Returns null while idle so the app bar keeps its normal height.
  static PreferredSizeWidget? of(FlutterOtaProgress update) =>
      update.stage == FlutterOtaStage.idle ? null : _UpdateBar(update: update);

  final FlutterOtaProgress update;

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = update.stage == FlutterOtaStage.failed
        ? theme.colorScheme.error
        : theme.colorScheme.onPrimaryContainer;
    final text = theme.textTheme.bodySmall?.copyWith(color: color);

    return SizedBox(
      height: preferredSize.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A null fraction means the size is unknown, and the bar spins
          // instead of sitting at zero.
          if (update.isBusy)
            LinearProgressIndicator(value: update.fraction, minHeight: 3)
          else
            const SizedBox(height: 3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      update.label,
                      overflow: TextOverflow.ellipsis,
                      style: text,
                    ),
                  ),
                  if (update.stage == FlutterOtaStage.downloading &&
                      update.total > 0)
                    Text(
                      '${_mb(update.received)} / ${_mb(update.total)} MB',
                      style: text,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}

/// Which snapshot is running, and what is queued for next launch.
class _StateCard extends StatelessWidget {
  const _StateCard({required this.state});

  final FlutterOtaState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(
              context,
              'Running',
              state.patchActive
                  ? 'patch ${state.currentPatch}'
                  : 'the code in the APK',
            ),
            _row(
              context,
              'Staged',
              state.stagedPatch == 0
                  ? 'nothing'
                  : 'patch ${state.stagedPatch}, loads next launch',
            ),
            _row(context, 'Confirmed', state.confirmed ? 'yes' : 'not yet'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Flexible(child: Text(value)),
        ],
      ),
    );
  }
}
