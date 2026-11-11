import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/interaction_service.dart';
import 'kid_ui.dart';

class CommentThreadWidget extends StatefulWidget {
  final String announcementId;
  final UserModel currentUser;

  const CommentThreadWidget({
    super.key,
    required this.announcementId,
    required this.currentUser,
  });

  @override
  State<CommentThreadWidget> createState() => _CommentThreadWidgetState();
}

class _CommentThreadWidgetState extends State<CommentThreadWidget> {
  final InteractionService _service = InteractionService();
  StreamSubscription<List<CommentModel>>? _commentsSub;
  List<CommentModel> _comments = [];

  @override
  void initState() {
    super.initState();
    _commentsSub =
        _service
        .streamComments(widget.announcementId, viewer: widget.currentUser)
        .listen((comments) {
      if (mounted) {
        setState(() => _comments = comments);
      }
    });
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: context.divider),
          const SizedBox(height: 4),
          if (_comments.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                'No comments yet. Be the first to comment!',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                return _CommentTileWidget(
                  comment: _comments[index],
                  currentUser: widget.currentUser,
                  announcementId: widget.announcementId,
                  service: _service,
                );
              },
            ),
          const SizedBox(height: 8),
          _CommentComposeBar(
            announcementId: widget.announcementId,
            currentUser: widget.currentUser,
            service: _service,
          ),
        ],
      ),
    );
  }
}

// ── CommentTileWidget ──────────────────────────────────────────────────────────

class _CommentTileWidget extends StatelessWidget {
  final CommentModel comment;
  final UserModel currentUser;
  final String announcementId;
  final InteractionService service;

  const _CommentTileWidget({
    required this.comment,
    required this.currentUser,
    required this.announcementId,
    required this.service,
  });

  bool get _canDelete {
    return currentUser.role == UserRole.admin ||
        currentUser.role == UserRole.subAdmin ||
        currentUser.uid == comment.authorUid;
  }

  bool get _canEdit => currentUser.uid == comment.authorUid;

  String get _initials {
    final parts = comment.authorName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: comment.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_outlined, color: context.brand, size: 20),
            SizedBox(width: 8),
            Text('Edit comment',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          autofocus: true,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Edit your comment…',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty || newText == comment.text) {
                Navigator.pop(ctx);
                return;
              }
              try {
                await service.updateComment(
                  announcementId: announcementId,
                  commentId: comment.id,
                  newText: newText,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Failed to update comment. Please try again.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              _initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.brand,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (comment.visibility == 'staff') ...[
                      const AudienceBadge(audience: 'staff', dense: true),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        comment.authorRole,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.brand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.5),
                      ),
                    ),
                    if (_canEdit)
                      _EditButton(
                        onEdit: () => _showEditDialog(context),
                      ),
                    if (_canDelete)
                      _DeleteButton(
                        onDelete: () async {
                          try {
                            await service.deleteComment(
                              announcementId: announcementId,
                              commentId: comment.id,
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Failed to delete comment. Please try again.'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: comment.visibility == 'staff'
                        ? AppColors.grape.withValues(alpha: 0.14)
                        : context.softFill,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    comment.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: context.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeleteButton({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline,
          size: 14, color: AppColors.error),
      onPressed: onDelete,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Delete comment',
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onEdit;

  const _EditButton({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.edit_outlined,
          size: 14, color: context.brand),
      onPressed: onEdit,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Edit comment',
    );
  }
}

// ── CommentComposeBar ──────────────────────────────────────────────────────────

class _CommentComposeBar extends StatefulWidget {
  final String announcementId;
  final UserModel currentUser;
  final InteractionService service;

  const _CommentComposeBar({
    required this.announcementId,
    required this.currentUser,
    required this.service,
  });

  @override
  State<_CommentComposeBar> createState() => _CommentComposeBarState();
}

class _CommentComposeBarState extends State<_CommentComposeBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  bool _staffOnly = false;

  bool get _isStaff => widget.currentUser.role != UserRole.student;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await widget.service.addComment(
        announcementId: widget.announcementId,
        authorUid: widget.currentUser.uid,
        authorName: widget.currentUser.fullName,
        authorRole: widget.currentUser.role.label,
        text: text,
        visibility: _staffOnly ? 'staff' : 'everyone',
      );
      if (mounted) {
        _controller.clear();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to post comment. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isStaff)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  _staffOnly ? Icons.lock_rounded : Icons.public_rounded,
                  size: 14,
                  color: _staffOnly ? AppColors.grape : AppColors.sky,
                ),
                label: Text(_staffOnly ? 'Staff only' : 'Visible to everyone',
                    style: TextStyle(fontSize: 11.5, color: context.textPrimary)),
                selected: _staffOnly,
                onSelected: (v) => setState(() => _staffOnly = v),
              ),
            ]),
          ),
        Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            widget.currentUser.initials,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: context.brand,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendComment(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: _staffOnly ? 'Internal note for staff…' : 'Write a comment…',
              hintStyle: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: context.divider,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: context.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              isDense: true,
              suffixIcon: _isSending
                  ? Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.brand,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.send_rounded,
                          size: 18, color: context.brand),
                      onPressed: _sendComment,
                      tooltip: 'Send comment',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
            ),
          ),
        ),
      ],
    ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
