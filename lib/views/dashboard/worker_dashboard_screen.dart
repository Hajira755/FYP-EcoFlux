// lib/views/dashboard/worker_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/worker_dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/complaint_model.dart';
import '../complaint/worker_report_detail_screen.dart';
import '../profile/worker_profile_screen.dart';
import '../../widgets/common/notification_bell.dart';

// ── Design tokens — green theme matching citizen & admin dashboard ────────────
const _kBlue         = Color(0xFF1565C0);   // kept for active/progress accents
const _kGreen        = Color(0xFF2E7D32);
const _kGreenDark    = Color(0xFF1B5E20);
const _kOrange       = Color(0xFFE65100);
const _kRed          = Color(0xFFC62828);
const _kBg           = Color(0xFFF4F6F9);

class WorkerDashboardScreen extends StatefulWidget {
  final String workerName;
  const WorkerDashboardScreen({super.key, required this.workerName});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _bottomIndex = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      final uid    = authVM.currentUser?.uid;
      if (uid != null) {
        final workerVM =
        Provider.of<WorkerDashboardViewModel>(context, listen: false);
        workerVM.listenToAssignedReports(uid);
        workerVM.loadWorkerProfile(uid);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workerVM = Provider.of<WorkerDashboardViewModel>(context);
    final authVM   = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _buildBody(workerVM, authVM),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody(
      WorkerDashboardViewModel workerVM, AuthViewModel authVM) {
    switch (_bottomIndex) {
      case 0:  return _HomeTab(workerVM: workerVM, authVM: authVM,
          workerName: widget.workerName);
      case 1:  return _TasksTab(workerVM: workerVM);
      case 2:  return WorkerProfileScreen(
          workerId: authVM.currentUser?.uid ?? '',
          workerVM: workerVM);
      default: return _HomeTab(workerVM: workerVM, authVM: authVM,
          workerName: widget.workerName);
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kGreen,
        unselectedItemColor: Colors.grey[500],
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        onTap: (i) => setState(() => _bottomIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HOME TAB
// ══════════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.workerVM,
    required this.authVM,
    required this.workerName,
  });
  final WorkerDashboardViewModel workerVM;
  final AuthViewModel            authVM;
  final String                   workerName;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverToBoxAdapter(child: _buildStats()),
        SliverToBoxAdapter(child: _buildSectionTitle('Active Tasks')),
        workerVM.isLoading
            ? const SliverToBoxAdapter(
            child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _kBlue),
                )))
            : workerVM.pendingReports.isEmpty &&
            workerVM.activeReports.isEmpty
            ? SliverToBoxAdapter(child: _buildEmptyTasks())
            : SliverList(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) {
              final active = [
                ...workerVM.activeReports,
                ...workerVM.pendingReports
              ];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _WorkerTaskCard(report: active[i]),
              );
            },
            childCount: workerVM.activeReports.length +
                workerVM.pendingReports.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final initial = workerName.isNotEmpty ? workerName[0].toUpperCase() : 'W';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreenDark, _kGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _kGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FIELD WORKER',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 1)),
                Text(workerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('On Duty',
                      style: TextStyle(
                          color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ),
          NotificationBell(userId: authVM.currentUser?.uid ?? ''),
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: Colors.white70),
            onPressed: () => authVM.logout(),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatBox(
              label: 'Assigned',
              value: workerVM.totalAssigned,
              color: _kGreen),
          const SizedBox(width: 10),
          _StatBox(
              label: 'Active',
              value: workerVM.totalPending,
              color: _kOrange),
          const SizedBox(width: 10),
          _StatBox(
              label: 'Completed',
              value: workerVM.totalCompleted,
              color: _kBlue),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Text(title,
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.bold)),
  );

  Widget _buildEmptyTasks() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 52, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No active tasks',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('All caught up! Great work.',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  TASKS TAB — shows all reports with filter
// ══════════════════════════════════════════════════════════════════════════════
class _TasksTab extends StatefulWidget {
  const _TasksTab({required this.workerVM});
  final WorkerDashboardViewModel workerVM;

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  String _filter = 'All';
  final _filters = ['All', 'Pending', 'Active', 'Completed'];

  @override
  Widget build(BuildContext context) {
    List<ComplaintModel> list;
    switch (_filter) {
      case 'Pending':
        list = widget.workerVM.pendingReports;
        break;
      case 'Active':
        list = widget.workerVM.activeReports;
        break;
      case 'Completed':
        list = widget.workerVM.completedReports;
        break;
      default:
        list = widget.workerVM.assignedReports;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('My Tasks',
              style:
              TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f   = _filters[i];
              final sel = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _kGreen : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                        sel ? _kGreen : Colors.grey[300]!),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          color:
                          sel ? Colors.white : Colors.grey[700],
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13)),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 52, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No $_filter tasks',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15)),
              ],
            ),
          )
              : ListView.separated(
            padding:
            const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _WorkerTaskCard(report: list[i]),
          ),
        ),
      ],
    );
  }
}

// ── Task Card (tappable → WorkerReportDetailScreen) ───────────────────────────
class _WorkerTaskCard extends StatelessWidget {
  const _WorkerTaskCard({required this.report});
  final ComplaintModel report;

  @override
  Widget build(BuildContext context) {
    final isEscalated = report.status.toUpperCase() == 'ESCALATED';
    final isHigh      = report.priority.toLowerCase() == 'high';
    final isDone      = report.status.toUpperCase() == 'COMPLETED';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                WorkerReportDetailScreen(report: report),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isDone
                    ? _kGreen
                    : isEscalated
                    ? _kRed
                    : isHigh
                    ? _kOrange
                    : _kGreen,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _priorityBadge(isEscalated, isHigh, isDone),
                  const Spacer(),
                  _statusBadge(report.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(report.category,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              if (report.description.isNotEmpty)
                Text(report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(_timeAgo(report.timestamp!.toDate()),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Quick action row
              if (!isDone)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkerReportDetailScreen(report: report),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined,
                            size: 16),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kGreen,
                          side: const BorderSide(color: _kGreen),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityBadge(bool escalated, bool high, bool done) {
    if (done) return const SizedBox.shrink();
    if (escalated) return _chip('⚠ ESCALATED', _kRed);
    if (high) return _chip('HIGH PRIORITY', _kOrange);
    return _chip(report.priority.toUpperCase(), _kBlue);
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold)),
  );

  Widget _statusBadge(String status) {
    Color c;
    switch (status.toUpperCase()) {
      case 'COMPLETED':   c = _kGreen;  break;
      case 'IN_PROGRESS': c = _kBlue;   break;
      case 'ESCALATED':   c = _kRed;    break;
      default:            c = _kOrange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.toUpperCase().replaceAll('_', ' '),
          style: TextStyle(
              color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    return '${d.inMinutes}m ago';
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label, required this.value, required this.color});
  final String label;
  final int    value;
  final Color  color;


  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border:
          Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(value.toString(),
                  key: ValueKey(value),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}