import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final void Function(String text) onSend;
  final bool enabled;
  final String? prefillText; // set to prefill the input, cleared after consumption

  const MessageInput({super.key, required this.onSend, this.enabled = true, this.prefillText});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  String? _lastPrefill;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      }
    });
  }

  @override
  void didUpdateWidget(MessageInput old) {
    super.didUpdateWidget(old);
    if (widget.prefillText != null && widget.prefillText != _lastPrefill) {
      _lastPrefill = widget.prefillText;
      _controller.text = widget.prefillText!;
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '说点什么...',
                  hintStyle: TextStyle(color: theme.colorScheme.outline.withOpacity(0.6)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: IconButton.filled(
                onPressed: _hasText && widget.enabled ? _send : null,
                icon: const Icon(Icons.send_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: _hasText
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
