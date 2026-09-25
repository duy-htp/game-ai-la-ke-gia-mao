import 'dart:async';

import 'package:flutter/material.dart';

class GameCountdown extends StatefulWidget {
  const GameCountdown({
    required this.endsAt,
    required this.serverNow,
    required this.onElapsed,
    super.key,
  });
  final DateTime endsAt;
  final DateTime serverNow;
  final VoidCallback onElapsed;
  @override
  State<GameCountdown> createState() => _GameCountdownState();
}

class _GameCountdownState extends State<GameCountdown> {
  Timer? _timer;
  late DateTime _localDeadline;
  bool _fired = false;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant GameCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt ||
        oldWidget.serverNow != widget.serverNow) {
      _reset();
    }
  }

  void _reset() {
    _timer?.cancel();
    _fired = false;
    _localDeadline = DateTime.now().add(
      widget.endsAt.difference(widget.serverNow),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    if (!_localDeadline.isAfter(DateTime.now()) && !_fired) {
      _fired = true;
      widget.onElapsed();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _localDeadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 3599);
    return Text(
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
      key: const Key('game-countdown'),
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}
