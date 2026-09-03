import 'package:flutroid_package/flutroid_package.dart';
import 'package:flutter/material.dart';

/// Edit this, rebuild, and ship it with `flutroid patch` — seeing it change
/// after a cold start is the proof that the downloaded snapshot was loaded.
const String kBuildMarker = 'hello from the APK 12:02 PM';

/// Where the Flutroid backend is reachable from the device.
///
/// `10.0.2.2` is the host machine as seen from the Android emulator; on a
/// physical device use your machine's LAN address.
const String kUpdateUrl = 'http://10.0.2.2:8080';

Future<void> main() async {
  await Flutroid.initialize(updateUrl: kUpdateUrl);
  runApp(const FlutroidDemo());
}

class FlutroidDemo extends StatelessWidget {
  const FlutroidDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutroid',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    final message = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  Future<String> _checkForUpdate() async {
    final staged = await Flutroid.instance.checkForUpdate();
    return staged == null
        ? 'Up to date.'
        : 'Staged patch $staged — restart the app to load it.';
  }

  Future<String> _rollback() async {
    await Flutroid.instance.rollback();
    return 'Rolled back. Restart to run the code in the APK.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = Flutroid.instance.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Flutroid')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(kBuildMarker, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                Flutroid.instance.releaseVersion,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              _StateCard(state: state),
              const SizedBox(height: 24),
              if (_message != null) ...[
                Text(_message!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _busy ? null : () => _run(_checkForUpdate),
                child: const Text('Check for update'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _run(_rollback),
                child: const Text('Roll back to the bundled code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.state});

  final FlutroidState state;

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
