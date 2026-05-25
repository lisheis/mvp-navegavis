import 'package:flutter/material.dart';

/// Animated FAB for voice command activation.
class VoiceCommandFab extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;

  const VoiceCommandFab({
    super.key,
    required this.isListening,
    required this.onTap,
  });

  @override
  State<VoiceCommandFab> createState() => _VoiceCommandFabState();
}

class _VoiceCommandFabState extends State<VoiceCommandFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isListening
        ? ScaleTransition(
            scale: _pulse,
            child: _fab(context, Colors.red),
          )
        : _fab(context, Theme.of(context).colorScheme.primary);
  }

  FloatingActionButton _fab(BuildContext context, Color color) =>
      FloatingActionButton.extended(
        onPressed: widget.onTap,
        backgroundColor: color,
        icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none),
        label: Text(widget.isListening ? 'Ouvindo...' : 'Comando de voz'),
      );
}

/// Inline voice status chip shown in navigation bar
class VoiceStatusChip extends StatelessWidget {
  final bool isListening;
  final String? text;

  const VoiceStatusChip({super.key, required this.isListening, this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isListening
            ? Colors.red.withOpacity(0.85)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isListening ? Icons.mic : Icons.mic_none,
              size: 16, color: Colors.white),
          if (text != null) ...[
            const SizedBox(width: 6),
            Text(text!,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
