import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/citizen_dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/complaint_viewmodel.dart';
import '../../core/constants/app_constants.dart';
import '../../models/complaint_model.dart';
import '../../widgets/sync_status_banner.dart';
import '../../widgets/common/notification_bell.dart';

// ── Color tokens ──────────────────────────────────────────────────────────────
const _kGreen        = Color(0xFF2E7D32);
const _kGreenLight   = Color(0xFF66BB6A);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);

class CitizenDashboardScreen extends StatefulWidget {
  final String userName;
  const CitizenDashboardScreen({super.key, required this.userName});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId =
          Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
      if (userId != null) {
        // Load static stats
        Provider.of<CitizenDashboardViewModel>(context, listen: false)
            .loadDashboardStats(userId);
        // Real-time listener → counts auto-update whenever a report is added/updated
        Provider.of<ComplaintViewModel>(context, listen: false)
            .listenToUserComplaints(userId);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Rank helpers ────────────────────────────────────────────────────────────
  String _rankLabel(int pts) {
    if (pts >= 500) return '🥇 Gold Citizen';
    if (pts >= 200) return '🥈 Silver Citizen';
    return '🥉 Bronze Citizen';
  }

  double _rankProgress(int pts) {
    if (pts >= 500) return 1.0;
    if (pts >= 200) return (pts - 200) / 300.0;
    return pts / 200.0;
  }

  String _rankNext(int pts) {
    if (pts >= 500) return 'Top rank achieved! 🎉';
    if (pts >= 200) return '${500 - pts} pts to Gold';
    return '${200 - pts} pts to Silver';
  }

  // ── Navigate to detail ──────────────────────────────────────────────────────
  void _openDetail(ComplaintModel report) {
    Navigator.pushNamed(
      context,
      AppConstants.reportDetailRoute,   // add this route to your AppConstants
      arguments: report,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dashVM     = Provider.of<CitizenDashboardViewModel>(context);
    final complaintVM = Provider.of<ComplaintViewModel>(context);
    final authVM     = Provider.of<AuthViewModel>(context);

    // Derive counts LIVE from the real-time complaint list
    final all       = complaintVM.userComplaints;
    final total     = all.length;
    final resolved  = all.where((c) => c.status.toUpperCase() == 'COMPLETED').length;
    final pending   = all.where((c) =>
    c.status.toUpperCase() == 'PENDING' ||
        c.status.toUpperCase() == 'ESCALATED').length;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: dashVM.isLoading && all.isEmpty
            ? _buildShimmer()
            : FadeTransition(
          opacity: _fadeAnim,
          child: RefreshIndicator(
            color: _kGreen,
            onRefresh: () async {
              final uid = authVM.currentUser?.uid;
              if (uid != null) {
                await dashVM.loadDashboardStats(uid);
              }
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: _buildHeader(authVM, dashVM.civicPoints)),
                // Shows automatically ONLY when there are offline/pending
                // reports in the local queue — hidden otherwise.
                const SliverToBoxAdapter(child: SyncStatusBanner()),
                SliverToBoxAdapter(child: _buildActionCards()),
                SliverToBoxAdapter(
                    child: _buildStats(total, resolved, pending)),
                SliverToBoxAdapter(
                    child: _buildCivicPoints(dashVM.civicPoints)),
                SliverToBoxAdapter(
                    child: _buildRecentReportsHeader(all.length)),
                all.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildReportTile(all[i]),
                    childCount: all.length,
                  ),
                ),
                SliverToBoxAdapter(child: _buildEcoTip()),
                const SliverToBoxAdapter(
                    child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(AuthViewModel authVM, int civicPts) {
    final initial = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase()
        : '?';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), _kGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              initial,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WELCOME BACK,',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        letterSpacing: 1)),
                Text(
                  widget.userName.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _rankLabel(civicPts),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          NotificationBell(userId: authVM.currentUser?.uid ?? ''),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(authVM),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(AuthViewModel authVM) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) authVM.logout();
  }

  // ── ACTION CARDS ─────────────────────────────────────────────────────────────
  Widget _buildActionCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          _ActionCard(
            icon: Icons.add_circle_rounded,
            label: 'New Report',
            color: _kGreen,
            onTap: () => Navigator.pushNamed(
                context, AppConstants.newReportRoute),
          ),
          const SizedBox(width: 10),
          _ActionCard(
            icon: Icons.bar_chart_rounded,
            label: 'My Reports',
            color: Colors.blue[700]!,
            onTap: () => Navigator.pushNamed(
                context, AppConstants.trackComplaintRoute),
          ),
          const SizedBox(width: 10),
          _ActionCard(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Feedback',
            color: Colors.orange[700]!,
            onTap: () =>
                Navigator.pushNamed(context, AppConstants.feedbackRoute),
          ),
        ],
      ),
    );
  }

  // ── STATS (live from complaintVM) ────────────────────────────────────────────
  Widget _buildStats(int total, int resolved, int pending) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          _StatCard(label: 'Total',    value: total,    color: Colors.blue[700]!),
          const SizedBox(width: 10),
          _StatCard(label: 'Resolved', value: resolved, color: _kGreen),
          const SizedBox(width: 10),
          _StatCard(label: 'Pending',  value: pending,  color: Colors.orange[700]!),
        ],
      ),
    );
  }

  // ── CIVIC POINTS ─────────────────────────────────────────────────────────────
  Widget _buildCivicPoints(int pts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                  color: _kGreenSurface, shape: BoxShape.circle),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(pts.toString(),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kGreen)),
                  const Text('pts',
                      style: TextStyle(fontSize: 10, color: _kGreenLight)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_rankLabel(pts),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_rankNext(pts),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _rankProgress(pts),
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(_kGreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RECENT REPORTS HEADER ────────────────────────────────────────────────────
  Widget _buildRecentReportsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Row(
        children: [
          const Text('My Reports',
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kGreenSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    color: _kGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ── REPORT TILE (tappable) ───────────────────────────────────────────────────
  Widget _buildReportTile(ComplaintModel report) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetail(report),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Category icon bubble
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: report.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _categoryIcon(report.category),
                    color: report.statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + address
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.category,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              report.address.isNotEmpty
                                  ? report.address
                                  : 'Location not set',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (report.timestamp != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(report.timestamp!.toDate()),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status chip
                _StatusBadge(status: report.status),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Overflowing Bin':  return Icons.delete_outline;
      case 'Illegal Dumping':  return Icons.warning_amber_outlined;
      case 'Uncollected Waste':return Icons.recycling;
      default:                 return Icons.report_gmailerrorred_outlined;
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]}, ${dt.year}';
  }

  // ── EMPTY STATE ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No reports yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text("Tap 'New Report' to report a waste issue",
                style:
                TextStyle(fontSize: 13, color: Colors.grey[400])),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppConstants.newReportRoute),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create First Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ECO TIP ──────────────────────────────────────────────────────────────────
  Widget _buildEcoTip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), _kGreenLight]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kGreen.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.eco_rounded, color: Colors.white, size: 32),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Eco Tip of the Day',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(height: 4),
                  Text(
                    'Always separate organic waste from recyclables to speed up collection!',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SHIMMER ──────────────────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(height: 90, radius: 20),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _shimmer(height: 80, radius: 14),
              ),
            )),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _shimmer(height: 70, radius: 14),
              ),
            )),
          ),
          const SizedBox(height: 16),
          _shimmer(height: 80, radius: 14),
          const SizedBox(height: 12),
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _shimmer(height: 72, radius: 14),
          )),
        ],
      ),
    );
  }

  Widget _shimmer({required double height, double radius = 8}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── BOTTOM NAV ────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kGreen,
        unselectedItemColor: Colors.grey[500],
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        onTap: (index) {
          if (index == 0 && _currentIndex == 0) return;
          setState(() => _currentIndex = index);
          switch (index) {
            case 1:
              Navigator.pushNamed(context, AppConstants.newReportRoute)
                  .then((_) => setState(() => _currentIndex = 0));
              break;
            case 2:
              Navigator.pushNamed(context, AppConstants.trackComplaintRoute)
                  .then((_) => setState(() => _currentIndex = 0));
              break;
            case 3:
              Navigator.pushNamed(context, AppConstants.profileRoute)
                  .then((_) => setState(() => _currentIndex = 0));
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline_rounded),
              activeIcon: Icon(Icons.add_circle_rounded),
              label: 'Report'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Status'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Extracted small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                value.toString(),
                key: ValueKey(value),
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return Colors.green[700]!;
      case 'IN_PROGRESS': return Colors.blue[700]!;
      case 'ASSIGNED':    return Colors.blue[700]!;
      case 'ESCALATED':   return Colors.red[700]!;
      default:            return Colors.orange[700]!;
    }
  }

  String get _label {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return 'Done';
      case 'IN_PROGRESS': return 'Active';
      case 'ASSIGNED':    return 'Assigned';
      case 'ESCALATED':   return 'Escalated';
      default:            return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(_label,
          style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}