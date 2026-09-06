import 'dart:async';

/// Runs [action] once after the last [call] + delay. For note autosave.
class Debouncer {
  Debouncer(this.delay, this.action);

  final Duration delay;
  final void Function() action;
  Timer? _timer;

  void call() {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }

  bool get hasPending => _timer?.isActive ?? false;

  void flush() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = null;
      action();
    }
  }

  void dispose() => _timer?.cancel();
}
