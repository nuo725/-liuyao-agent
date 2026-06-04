import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/audio_service.dart';
import '../../state/ritual_state.dart';

class TypewriterScreen extends ConsumerStatefulWidget {
  const TypewriterScreen({super.key});

  @override
  ConsumerState<TypewriterScreen> createState() => _TypewriterScreenState();
}

class _TypewriterScreenState extends ConsumerState<TypewriterScreen> {
  String _displayText = '';
  static const String _fullText = '纹理已成。不疾不徐...';

  void _toggleMute() {
    audioService.toggleMute();
  }

  Future<void> _startTypewriter() async {
    for (int i = 0; i < _fullText.length; i++) {
      if (!mounted) return;
      setState(() {
        _displayText = _fullText.substring(0, i + 1);
      });
      audioService.playTypingSound();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // 打字完成，延迟2秒后直接进入presentation（跳过suspension）
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pop();
      // 直接推进到presentation
      ref.read(ritualStateProvider.notifier).nextPhase(); // action -> suspension
      ref.read(ritualStateProvider.notifier).nextPhase(); // suspension -> presentation
    }
  }

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _displayText,
                style: const TextStyle(
                  color: Color(0xFF3C3C3C),
                  fontSize: 20,
                  height: 2.0,
                  letterSpacing: 4.0,
                  fontFamily: 'serif',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: audioService.isMutedNotifier,
              builder: (context, isMuted, child) {
                return GestureDetector(
                  onTap: _toggleMute,
                  child: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    size: 22,
                    color: const Color(0xFFBDBDBD),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
