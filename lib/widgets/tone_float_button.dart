import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Draggable floating button for quick reply tone switching.
/// Long-press to drag, tap to show tone picker.
class ToneFloatButton extends StatefulWidget {
  const ToneFloatButton({super.key});

  @override
  State<ToneFloatButton> createState() => _ToneFloatButtonState();
}

class _ToneFloatButtonState extends State<ToneFloatButton> {
  // Initial position: bottom-right corner
  double _x = 0;
  double _y = 0;
  bool _initialized = false;
  String _tone = '正常';

  @override
  void initState() {
    super.initState();
    AuthService.getQuickReplyTone().then((t) {
      if (mounted) setState(() => _tone = t);
    });
  }

  IconData _toneIcon() {
    switch (_tone) {
      case '下流': return Icons.whatshot;
      case '优雅': return Icons.auto_awesome;
      default:    return Icons.chat_bubble_outline;
    }
  }

  void _showPicker() {
    final overlay = Overlay.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;

    // Direction: toward screen center from the button.
    final toLeft = _x + 21 > centerX;   // button is right of center → pop left
    final toTop  = _y + 21 > centerY;   // button is below center → pop up

    // Picker position anchored to button edge.
    double pickerLeft = toLeft ? _x - 156 : _x + 50;
    double pickerTop  = toTop  ? _y - 40 : _y + 50;
    pickerLeft = pickerLeft.clamp(8.0, screenWidth - 164);
    pickerTop  = pickerTop.clamp(8.0, screenHeight - 56);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        onTap: () => entry.remove(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            Positioned(
              left: pickerLeft,
              top: pickerTop,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: AuthService.quickReplyTones.map((t) {
                      final selected = _tone == t;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(t, style: TextStyle(fontSize: 12,
                              color: selected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface)),
                          selected: selected,
                          selectedColor: theme.colorScheme.primary,
                          onSelected: (_) {
                            setState(() => _tone = t);
                            AuthService.setQuickReplyTone(t);
                            entry.remove();
                          },
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (!_initialized) {
      _x = size.width - 56;
      _y = size.height * 0.45;
      _initialized = true;
    }

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _x = (_x + d.delta.dx).clamp(0.0, size.width - 48);
            _y = (_y + d.delta.dy).clamp(0.0, size.height - 48);
          });
        },
        onTap: _showPicker,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            ),
            child: Icon(_toneIcon(), size: 20,
                color: Theme.of(context).colorScheme.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}
