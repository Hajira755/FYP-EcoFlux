import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/feedback_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// CHANGES FOR REPORT-SPECIFIC FEEDBACK (search "NEW" comments below):
///
/// This screen still works exactly as before when opened with no arguments
/// (e.g. from the dashboard's generic "Feedback" card — reportId stays null).
///
/// To give feedback about ONE specific report, navigate like this:
/// ```dart
/// Navigator.pushNamed(
///   context,
///   AppConstants.feedbackRoute,
///   arguments: {
///     'reportId': report.complaintId,
///     'reportCategory': report.category,
///   },
/// );
/// ```
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();

  // NEW — read optional arguments once, after the widget is mounted.
  String? _reportId;
  String? _reportCategory;
  bool _argsLoaded = false;

  static const _gradStart = Color(0xFF32691A);
  static const _gradEnd   = Color(0xFF528817);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // NEW — pull reportId/reportCategory out of route arguments, if any.
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _reportId = args['reportId'] as String?;
        _reportCategory = args['reportCategory'] as String?;
      }
      _argsLoaded = true;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;

    final feedbackVM = Provider.of<FeedbackViewModel>(context, listen: false);
    final authVM     = Provider.of<AuthViewModel>(context, listen: false);

    await feedbackVM.submitFeedback(
      rating:   _rating,
      comment:  _commentController.text.trim(),
      userId:   authVM.currentUser?.uid ?? '',
      userName: authVM.currentUser?.email.split('@')[0] ?? 'User',
      reportId: _reportId,               // NEW
      reportCategory: _reportCategory,   // NEW
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      Navigator.pop(context);
    }
  }

  Widget _gradientButton({
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: onTap == null
            ? const LinearGradient(colors: [Color(0xFFB0BEC5), Color(0xFFB0BEC5)])
            : const LinearGradient(
          colors: [_gradStart, _gradEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: onTap == null
            ? []
            : [
          BoxShadow(
            color: _gradStart.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedbackVM = Provider.of<FeedbackViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_gradStart, _gradEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Feedback',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.4,
          ),
        ),
        centerTitle: true,
      ),

      backgroundColor: const Color(0xFFF5F7F5),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_gradStart, _gradEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _gradStart.withValues(alpha: 0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.rate_review_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'How was your experience?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2D1B),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // NEW — shows which report this feedback is about, if any.
                  if (_reportCategory != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Regarding: $_reportCategory',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _gradStart,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 6),
                  const Text(
                    'Your feedback helps us improve.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8A9E8A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                          (i) => GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: AnimatedScale(
                          scale: i < _rating ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 46,
                            color: i < _rating ? const Color(0xFFFFC107) : const Color(0xFFCFD8DC),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF2E3D2E)),
                    decoration: InputDecoration(
                      hintText: 'Write your comment here…',
                      hintStyle: const TextStyle(color: Color(0xFFAABBAA), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF0F5F0),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _gradStart, width: 1.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            _gradientButton(
              onTap: feedbackVM.isSubmitting ? null : _submit,
              child: feedbackVM.isSubmitting
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text(
                'Submit Feedback',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
