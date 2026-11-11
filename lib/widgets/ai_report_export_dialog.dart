import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/student_model.dart';
import '../services/report_service.dart';
import '../services/share_service.dart';
import 'package:printing/printing.dart';

class AiReportExportDialog extends StatelessWidget {
  final String title;
  final String reportText;
  final StudentModel student;

  const AiReportExportDialog({
    super.key,
    required this.title,
    required this.reportText,
    required this.student,
  });

  static void show(BuildContext context,
      {required String title,
      required String reportText,
      required StudentModel student}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiReportExportDialog(
        title: title,
        reportText: reportText,
        student: student,
      ),
    );
  }

  void _showShareMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: AppColors.mint),
              title: const Text('Share as text (WhatsApp, Facebook, SMS…)'),
              onTap: () {
                Navigator.pop(ctx);
                ShareService.shareText(reportText, subject: title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.coral),
              title: const Text('Share as PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await ReportService.textReportPdf(
                    title: title, subtitle: student.fullName, body: reportText);
                await Printing.sharePdf(
                    bytes: bytes, filename: '${title.replaceAll(' ', '_')}.pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_rounded, color: AppColors.sky),
              title: const Text('Print'),
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await ReportService.textReportPdf(
                    title: title, subtitle: student.fullName, body: reportText);
                await Printing.layoutPdf(onLayout: (_) async => bytes, name: title);
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome,
                      color: context.brand, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Student: ${student.fullName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Report Content Preview Box
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: context.divider.withValues(alpha: 0.8)),
                ),
                child: SelectableText(
                  reportText,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: theme.textTheme.bodyLarge?.color,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                top: BorderSide(color: context.divider),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: reportText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Report copied to clipboard!'),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showShareMenu(context),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share / Print'),
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
