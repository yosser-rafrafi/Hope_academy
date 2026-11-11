import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/user_model.dart';
import '../services/interaction_service.dart';
import 'reaction_picker_widget.dart';

class InteractionBarWidget extends StatefulWidget {
  final String announcementId;
  final Map<String, int> initialReactionCounts;
  final int initialCommentCount;
  final UserModel currentUser;
  final VoidCallback onCommentToggle;

  const InteractionBarWidget({
    super.key,
    required this.announcementId,
    required this.initialReactionCounts,
    required this.initialCommentCount,
    required this.currentUser,
    required this.onCommentToggle,
  });

  @override
  State<InteractionBarWidget> createState() => _InteractionBarWidgetState();
}

class _InteractionBarWidgetState extends State<InteractionBarWidget> {
  final InteractionService _service = InteractionService();

  StreamSubscription<Map<String, int>>? _countsSub;
  StreamSubscription<String?>? _userReactionSub;
  StreamSubscription<int>? _commentCountSub;

  late Map<String, int> _optimisticCounts;
  String? _optimisticUserEmoji;
  late int _commentCount;

  OverlayEntry? _pickerOverlay;
  final GlobalKey _reactButtonKey = GlobalKey();

  bool get _isMock => widget.announcementId.startsWith('mock-');

  @override
  void initState() {
    super.initState();
    _optimisticCounts = Map<String, int>.from(widget.initialReactionCounts);
    _commentCount = widget.initialCommentCount;

    if (!_isMock) {
      _countsSub = _service
          .streamReactionCounts(widget.announcementId)
          .listen((counts) {
        if (mounted) {
          setState(() => _optimisticCounts = Map<String, int>.from(counts));
        }
      });

      _userReactionSub = _service
          .streamUserReaction(
              widget.announcementId, widget.currentUser.uid)
          .listen((emoji) {
        if (mounted) {
          setState(() => _optimisticUserEmoji = emoji);
        }
      });

      // Stream live comment count from the announcement document
      _commentCountSub = _service
          .streamCommentCount(widget.announcementId)
          .listen((count) {
        if (mounted) setState(() => _commentCount = count);
      });
    }
  }

  @override
  void dispose() {
    _countsSub?.cancel();
    _userReactionSub?.cancel();
    _commentCountSub?.cancel();
    _removePicker();
    super.dispose();
  }

  void _removePicker() {
    _pickerOverlay?.remove();
    _pickerOverlay = null;
  }

  void _showReactionPicker() {
    if (_pickerOverlay != null) {
      _removePicker();
      return;
    }

    final renderBox =
        _reactButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);

    _pickerOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent full-screen tap catcher
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removePicker,
            ),
          ),
          // Picker positioned above the button
          Positioned(
            left: offset.dx - 60,
            top: offset.dy - 68,
            child: ReactionPickerWidget(
              onEmojiSelected: (emoji) {
                _removePicker();
                _handleEmojiSelected(emoji);
              },
              onDismiss: _removePicker,
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_pickerOverlay!);
  }

  void _handleEmojiSelected(String emoji) {
    // Toggle off if same emoji, otherwise switch
    final newEmoji =
        _optimisticUserEmoji == emoji ? null : emoji;
    final previousEmoji = _optimisticUserEmoji;

    // Save pre-tap state for possible revert
    final previousCounts = Map<String, int>.from(_optimisticCounts);

    // Apply optimistic update
    setState(() {
      if (previousEmoji != null) {
        final prev = (_optimisticCounts[previousEmoji] ?? 1) - 1;
        if (prev <= 0) {
          _optimisticCounts.remove(previousEmoji);
        } else {
          _optimisticCounts[previousEmoji] = prev;
        }
      }
      if (newEmoji != null) {
        _optimisticCounts[newEmoji] =
            (_optimisticCounts[newEmoji] ?? 0) + 1;
      }
      _optimisticUserEmoji = newEmoji;
    });

    // Write to Firestore
    _service
        .setReaction(
          announcementId: widget.announcementId,
          userId: widget.currentUser.uid,
          emoji: newEmoji,
          previousEmoji: previousEmoji,
        )
        .catchError((error) {
      // Revert optimistic update on failure
      if (mounted) {
        setState(() {
          _optimisticCounts = previousCounts;
          _optimisticUserEmoji = previousEmoji;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update reaction. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// Returns emoji entries with count > 0, sorted by count descending.
  List<MapEntry<String, int>> _sortedReactions() {
    return _optimisticCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedReactions();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // ── Reaction summary ─────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // React button
                GestureDetector(
                  key: _reactButtonKey,
                  onTap: _isMock ? null : _showReactionPicker,
                  child: _isMock
                      ? _buildMutedReactLabel(theme)
                      : sorted.isEmpty
                          ? _buildMutedReactLabel(theme)
                          : _buildReactionSummary(sorted, theme),
                ),
              ],
            ),
          ),
          // ── Comment button ───────────────────────────────────────────────
          GestureDetector(
            onTap: _isMock ? null : widget.onCommentToggle,
            child: Opacity(
              opacity: _isMock ? 0.4 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_commentCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutedReactLabel(ThemeData theme) {
    return Opacity(
      opacity: _isMock ? 0.4 : 0.6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_reaction_outlined,
            size: 16,
            color: theme.textTheme.bodyMedium?.color,
          ),
          const SizedBox(width: 4),
          Text(
            'React',
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionSummary(
      List<MapEntry<String, int>> sorted, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sorted.map((entry) {
        final isActive = _optimisticUserEmoji == entry.key;
        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.15)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : context.divider,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.key, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 3),
              Text(
                '${entry.value}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? context.brand
                      : theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
