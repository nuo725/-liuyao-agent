import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RitualTriggerMode { touch, hardware }

class RitualTriggerState {
  final RitualTriggerMode mode;
  final bool deviceConnected;
  final int hardwareEventId;
  final List<int>? hardwareLines;
  final String? errorMessage;

  const RitualTriggerState({
    this.mode = RitualTriggerMode.touch,
    this.deviceConnected = false,
    this.hardwareEventId = 0,
    this.hardwareLines,
    this.errorMessage,
  });

  RitualTriggerState copyWith({
    RitualTriggerMode? mode,
    bool? deviceConnected,
    int? hardwareEventId,
    List<int>? hardwareLines,
    bool clearHardwareLines = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RitualTriggerState(
      mode: mode ?? this.mode,
      deviceConnected: deviceConnected ?? this.deviceConnected,
      hardwareEventId: hardwareEventId ?? this.hardwareEventId,
      hardwareLines: clearHardwareLines
          ? null
          : (hardwareLines ?? this.hardwareLines),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RitualTriggerNotifier extends Notifier<RitualTriggerState> {
  static const MethodChannel _channel =
      MethodChannel('zhouyi/hardware_bridge');
  Timer? _pollTimer;

  @override
  RitualTriggerState build() {
    final forceHardware = const bool.fromEnvironment('RITUAL_HARDWARE_MODE');

    final initial = forceHardware
        ? const RitualTriggerState(mode: RitualTriggerMode.hardware)
        : const RitualTriggerState();

    state = initial;
    _startPolling();
    ref.onDispose(() => _pollTimer?.cancel());
    return state;
  }

  void useTouchMode() {
    state = state.copyWith(
      mode: RitualTriggerMode.touch,
      clearError: true,
      clearHardwareLines: true,
    );
  }

  void useHardwareMode() {
    state = state.copyWith(mode: RitualTriggerMode.hardware, clearError: true);
  }

  void ingestHardwareLines(List<int> lines) {
    if (lines.length != 6) return;
    final normalized = lines.map((e) => e > 0 ? 1 : 0).toList();
    state = state.copyWith(
      mode: RitualTriggerMode.hardware,
      deviceConnected: true,
      hardwareEventId: state.hardwareEventId + 1,
      hardwareLines: normalized,
      clearError: true,
    );
  }

  Future<void> refreshHardwareState() async {
    try {
      final connected =
          await _channel.invokeMethod<bool>('isConnected') ?? false;
      state = state.copyWith(deviceConnected: connected, clearError: true);
    } catch (_) {
      state = state.copyWith(
        deviceConnected: false,
        errorMessage: '硬件连接检测失败，请检查蓝牙后重试。',
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshHardwareState(),
    );
  }
}

final ritualTriggerProvider =
    NotifierProvider<RitualTriggerNotifier, RitualTriggerState>(
      RitualTriggerNotifier.new,
    );
