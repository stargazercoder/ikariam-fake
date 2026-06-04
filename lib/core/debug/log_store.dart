import 'package:flutter/material.dart';

/// In-memory log store for debugging.
/// Filled by [log] calls throughout the app and displayed on /debug-logs.
class LogStore {
  static final LogStore instance = LogStore._();
  LogStore._();

  final List<_LogEntry> _entries = [];
  static const int maxEntries = 500;

  void add(String level, String message) {
    _entries.add(_LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    ));
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  List<_LogEntry> get entries => List.unmodifiable(_entries);

  void clear() => _entries.clear();
}

class _LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  _LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}

/// Convenience function called anywhere in the app.
void log(String message, {String level = 'info'}) {
  LogStore.instance.add(level, message);
}

/// Global key for the overlay entry — controlled from App.dart.
final debugLogsOverlayKey = GlobalKey<DebugLogsOverlayState>();

/// Floating overlay showing a live log count.
/// Hidden by default, shown via `debugLogsOverlayKey.currentState?.show()`.
class DebugLogsOverlay extends StatefulWidget {
  const DebugLogsOverlay({super.key});

  @override
  State<DebugLogsOverlay> createState() => DebugLogsOverlayState();
}

class DebugLogsOverlayState extends State<DebugLogsOverlay> {
  bool _visible = false;

  void show() => setState(() => _visible = true);
  void hide() => setState(() => _visible = false);
  void toggle() => setState(() => _visible = !_visible);

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return Positioned(
        bottom: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bug_report, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'LOG',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[900],
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Debug Logs',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: hide,
                    tooltip: 'Close (press D 5 times)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.orange),
                    onPressed: () {
                      LogStore.instance.clear();
                      setState(() {});
                    },
                    tooltip: 'Clear logs',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    onPressed: () {
                      final logs = LogStore.instance.entries
                          .map((e) => '[${e.timestamp}] ${e.level.toUpperCase()}: ${e.message}')
                          .join('\n');
                      // Copy to clipboard handled below
                    },
                    tooltip: 'Copy all',
                  ),
                ],
              ),
            ),
            // Log list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: LogStore.instance.entries.length,
                itemBuilder: (context, index) {
                  final entry = LogStore.instance.entries[index];
                  final color = _levelColor(entry.level);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 75,
                          child: Text(
                            _formatTime(entry.timestamp),
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ),
                        Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            entry.level.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.message,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'debug':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

/// Separate standalone page version — accessible at /debug-logs via browser.
class DebugLogsPage extends StatefulWidget {
  const DebugLogsPage({super.key});

  @override
  State<DebugLogsPage> createState() => _DebugLogsPageState();
}

class _DebugLogsPageState extends State<DebugLogsPage> {
  @override
  void initState() {
    super.initState();
    log('DebugLogsPage opened');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Debug Logs', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.orange),
            onPressed: () {
              LogStore.instance.clear();
              setState(() {});
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: LogStore.instance.entries.length,
        itemBuilder: (context, index) {
          final entry = LogStore.instance.entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    _formatTime(entry.timestamp),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _levelColor(entry.level).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    entry.level.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _levelColor(entry.level),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.message,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'error': return Colors.red;
      case 'warning': return Colors.orange;
      case 'info': return Colors.blue;
      case 'debug': return Colors.grey;
      default: return Colors.green;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}