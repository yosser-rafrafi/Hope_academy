import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// The five supported reaction emojis.
const List<String> kReactionEmojis = ['👍', '❤️', '😮', '😢', '😡'];

/// A floating emoji picker displayed as an OverlayEntry above the react button.
///
/// Animates in with a combined ScaleTransition + FadeTransition.
/// Tapping an emoji calls [onEmojiSelected]; tapping outside calls [onDismiss].
class ReactionPickerWidget extends StatefulWidget {
  final void Function(String emoji) onEmojiSelected;
  final VoidCallback onDismiss;

  const ReactionPickerWidget({
    super.key,
    required this.onEmojiSelected,
    required this.onDismiss,
  });

  @override
  State<ReactionPickerWidget> createState() => _ReactionPickerWidgetState();
}

class _ReactionPickerWidgetState extends State<ReactionPickerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onDismiss,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: Alignment.bottomCenter,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(30),
            color: Theme.of(context).cardColor,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: context.divider,
                  width: 1,
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: kReactionEmojis.map((emoji) {
                  return _EmojiButton(
                    emoji: emoji,
                    onTap: () => widget.onEmojiSelected(emoji),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 1.0,
      upperBound: 1.3,
      value: 1.0,
    );
    _scaleAnim = _hoverController;
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverController.forward(),
      onTapUp: (_) {
        _hoverController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _hoverController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
