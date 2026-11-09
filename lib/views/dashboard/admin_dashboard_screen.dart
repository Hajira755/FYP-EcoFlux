// lib/views/dashboard/admin_dashboard_screen.dart
//
// pubspec.yaml mein add karo:
//   fl_chart: ^0.68.0

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/complaint_model.dart';
import '../complaint/report_detail_admin_screen.dart';
import '../../widgets/common/notification_bell.dart';
import '../support/chat_thread_screen.dart';

// ── Design tokens — matching citizen dashboard green theme ────────────────────
const _kGreen        = Color(0xFF2E7D32);
const _kGreenDark    = Color(0xFF1B5E20);
const _kGreenLight   = Color(0xFF66BB6A);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);
const _kCard         = Colors.white;
const _kOrange       = Color(0xFFE65100);
const _kRed          = Color(0xFFC62828);
const _kBlue         = Color(0xFF1565C0);

class AdminDashboardScreen extends StatefulWidget {
  final String userName;
  const AdminDashboardScreen({super.key, required this.userName});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int    _tabIndex    = 0;
  String _searchQuery = '';
  String _statusFilter = 'All';

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  final List<String> _statusFilters = [
    'All', 'Pending', 'Assigned', 'In Progress', 'Escalated', 'Completed'
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = Provider.of<AdminDashboardViewModel>(context, listen: false);
      vm.loadAdminStats();
      vm.listenToWorkerMessages(); // ← messages listener start
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = Provider.of<AdminDashboardViewModel>(context);
    final authVM  = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildHeader(authVM, adminVM),
              _buildTabBar(adminVM),
              Expanded(child: _buildBody(adminVM)),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER — green gradient matching citizen dashboard ────────────────────
  Widget _buildHeader(AuthViewModel authVM, AdminDashboardViewModel adminVM) {
    final initial = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase()
        : 'A';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGreenDark, _kGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADMIN PANEL',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 1)),
                    Text(widget.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (adminVM.escalated > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('${adminVM.escalated} Escalated',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              NotificationBell(userId: authVM.currentUser?.uid ?? ''),
              IconButton(
                onPressed: () => _confirmLogout(authVM),
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 20),
                tooltip: 'Logout',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stat pills
          Row(
            children: [
              _MiniStat(label: 'Total',   value: adminVM.total,
                  color: Colors.white),
              _MiniStat(label: 'Pending', value: adminVM.pending,
                  color: Colors.orange[200]!),
              _MiniStat(label: 'Active',
                  value: adminVM.assigned + adminVM.inProgress,
                  color: Colors.lightBlue[200]!),
              _MiniStat(label: 'Done',    value: adminVM.completed,
                  color: Colors.greenAccent[200]!),
            ],
          ),
          const SizedBox(height: 14),

          // Search bar
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search reports, users…',
              hintStyle:
              const TextStyle(color: Colors.white54, fontSize: 14),
              prefixIcon:
              const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB BAR — Messages tab + unread badge ────────────────────────────────────
  Widget _buildTabBar(AdminDashboardViewModel adminVM) {
    final tabs = ['Reports', 'Analytics', 'Users', 'Workers', 'Messages'];
    return Container(
      color: _kCard,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? _kGreen : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: i == 4 // Messages tab — show unread badge
                    ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      tabs[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sel ? _kGreen : Colors.grey[500],
                        fontWeight: sel
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    if (adminVM.unreadMessageCount > 0)
                      Positioned(
                        top: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: _kRed,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${adminVM.unreadMessageCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                )
                    : Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sel ? _kGreen : Colors.grey[500],
                    fontWeight:
                    sel ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── BODY ─────────────────────────────────────────────────────────────────────
  Widget _buildBody(AdminDashboardViewModel adminVM) {
    if (adminVM.isLoading && adminVM.allReports.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: _kGreen));
    }
    switch (_tabIndex) {
      case 0:  return _buildReportsTab(adminVM);
      case 1:  return _buildAnalyticsTab(adminVM);
      case 2:  return _buildUsersTab(adminVM);
      case 3:  return _buildWorkersTab(adminVM);
      case 4:  return _buildMessagesTab(adminVM);
      default: return const SizedBox();
    }
  }

  // ── REPORTS TAB ──────────────────────────────────────────────────────────────
  Widget _buildReportsTab(AdminDashboardViewModel adminVM) {
    var reports = adminVM.prioritizedReports;
    if (_statusFilter != 'All') {
      final f = _statusFilter.toUpperCase().replaceAll(' ', '_');
      reports = reports.where((r) => r.status.toUpperCase() == f).toList();
    }
    if (_searchQuery.isNotEmpty) {
      reports = reports.where((r) =>
      r.category.toLowerCase().contains(_searchQuery) ||
          r.address.toLowerCase().contains(_searchQuery) ||
          r.description.toLowerCase().contains(_searchQuery)).toList();
    }

    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _statusFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f   = _statusFilters[i];
              final sel = _statusFilter == f;
              return GestureDetector(
                onTap: () => setState(() => _statusFilter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _kGreen : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? _kGreen : Colors.grey[300]!),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.grey[700],
                          fontWeight:
                          sel ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(children: [
            Text('${reports.length} reports',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]))
          ]),
        ),
        Expanded(
          child: reports.isEmpty
              ? _emptyState('No reports found')
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AdminReportTile(
              report: reports[i],
              workers: adminVM.workers,
              onAssign: (wId, wName) async {
                final ok = await adminVM.assignWorker(
                  reportId:   reports[i].complaintId,
                  workerId:   wId,
                  workerName: wName,
                );
                if (mounted) {
                  _showSnack(ok
                      ? ' Worker assigned successfully!'
                      : adminVM.errorMessage ?? 'Error',
                      color: ok ? _kGreen : _kRed);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── ANALYTICS TAB ────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab(AdminDashboardViewModel adminVM) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Report Status Overview'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDec(),
            child: Row(
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 45,
                      sections: _buildDonutSections(adminVM),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Legend('Pending',    Colors.orange[600]!,  adminVM.pending),
                      _Legend('Assigned',   Colors.blue[600]!,    adminVM.assigned),
                      _Legend('In Progress',Colors.cyan[600]!,    adminVM.inProgress),
                      _Legend('Escalated',  _kRed,                adminVM.escalated),
                      _Legend('Completed',  _kGreen,              adminVM.completed),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _SectionTitle(title: 'Weekly Reports (Last 7 Days)'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            decoration: _cardDec(),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxWeeklyCount(adminVM) + 2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => _kGreen,
                      getTooltipItem: (group, _, rod, __) {
                        final day = adminVM.weeklyReportData[group.x]['day'];
                        return BarTooltipItem(
                          '$day\n${rod.toY.toInt()} reports',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= adminVM.weeklyReportData.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              adminVM.weeklyReportData[idx]['day'],
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                        reservedSize: 24,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(adminVM),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          _SectionTitle(title: 'Quick Summary'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _SummaryCard('Total Reports', adminVM.total,
                  Icons.assignment_outlined, _kGreen),
              _SummaryCard('Escalated', adminVM.escalated,
                  Icons.warning_amber_rounded, _kRed),
              _SummaryCard('Resolved', adminVM.completed,
                  Icons.check_circle_outline, _kGreen),
              _SummaryCard('Active Workers', adminVM.workers.length,
                  Icons.engineering_outlined, _kBlue),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildDonutSections(AdminDashboardViewModel adminVM) {
    final total = adminVM.total == 0 ? 1 : adminVM.total;
    return [
      _pieSection(adminVM.pending,    Colors.orange[600]!, total),
      _pieSection(adminVM.assigned,   Colors.blue[600]!,   total),
      _pieSection(adminVM.inProgress, Colors.cyan[600]!,   total),
      _pieSection(adminVM.escalated,  _kRed,               total),
      _pieSection(adminVM.completed,  _kGreen,             total),
    ].where((s) => s.value > 0).toList();
  }

  PieChartSectionData _pieSection(int value, Color color, int total) {
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      radius: 30,
      title: value > 0 ? '${((value / total) * 100).round()}%' : '',
      titleStyle: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  List<BarChartGroupData> _buildBarGroups(AdminDashboardViewModel adminVM) {
    return adminVM.weeklyReportData.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: (e.value['count'] as int).toDouble(),
            gradient: const LinearGradient(
              colors: [_kGreenLight, _kGreen],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();
  }

  double _maxWeeklyCount(AdminDashboardViewModel adminVM) {
    if (adminVM.weeklyReportData.isEmpty) return 5;
    final max = adminVM.weeklyReportData
        .map((e) => e['count'] as int)
        .reduce((a, b) => a > b ? a : b);
    return max == 0 ? 5 : max.toDouble();
  }

  // ── USERS TAB ────────────────────────────────────────────────────────────────
  Widget _buildUsersTab(AdminDashboardViewModel adminVM) {
    var users = adminVM.users;
    if (_searchQuery.isNotEmpty) {
      users = users.where((u) =>
      (u['name'] ?? '').toLowerCase().contains(_searchQuery) ||
          (u['email'] ?? '').toLowerCase().contains(_searchQuery)).toList();
    }
    return users.isEmpty
        ? _emptyState('No users found')
        : ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _UserTile(
        user: users[i],
        onDelete: () => _confirmDeleteUser(adminVM, users[i]['id']),
        onEdit: () => _showEditUserSheet(adminVM, users[i]),
      ),
    );
  }

  // ── WORKERS TAB ──────────────────────────────────────────────────────────────
  Widget _buildWorkersTab(AdminDashboardViewModel adminVM) {
    var workers = adminVM.workers;
    if (_searchQuery.isNotEmpty) {
      workers = workers.where((w) =>
          (w['name'] ?? '').toLowerCase().contains(_searchQuery)).toList();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddWorkerSheet(adminVM),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add New Worker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: workers.isEmpty
              ? _emptyState('No workers found')
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: workers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _WorkerManageTile(
              worker: workers[i],
              onDelete: () => _confirmDeleteWorker(adminVM, workers[i]['id']),
            ),
          ),
        ),
      ],
    );
  }

  // ── MESSAGES TAB — Worker → Admin support messages ────────────────────────
  Widget _buildMessagesTab(AdminDashboardViewModel adminVM) {
    final messages = adminVM.workerMessages;

    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.support_agent_rounded,
                  color: _kGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Worker Messages (${messages.length})',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (adminVM.unreadMessageCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${adminVM.unreadMessageCount} unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        // Message list
        Expanded(
          child: messages.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_chat_read_outlined,
                    size: 52, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No messages from workers',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 15)),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: messages.length,
            itemBuilder: (ctx, i) {
              final m       = messages[i];
              final isUnread = m['isRead'] == false;
              final ts = (m['timestamp'] as Timestamp?)?.toDate();
              final timeStr = ts != null
                  ? '${ts.day}/${ts.month}  ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}'
                  : '';
              final reportId = (m['reportId'] as String? ?? '');
              final shortId  = reportId.length > 8
                  ? reportId.substring(0, 8)
                  : reportId;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(
                      messageId:   m['id'],
                      reportId:    reportId,
                      workerId:    m['workerId'] as String? ?? '',
                      isAdminView: true,
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUnread
                        ? const Color(0xFFFFF8E1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isUnread
                          ? const Color(0xFFFFCC02)
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: avatar + name + badge + time
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _kGreenSurface,
                            child: Text(
                              (m['workerName'] as String? ?? 'W')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: _kGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['workerName'] ?? 'Worker',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                                Text(
                                  'Report: $shortId…',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: _kRed,
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              child: const Text('NEW',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 6),
                          Text(timeStr,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400])),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Message body
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          m['message'] ?? '',
                          style: const TextStyle(
                              fontSize: 13, height: 1.5),
                        ),
                      ),

                      // Reply + Mark as read buttons
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isUnread)
                            TextButton.icon(
                              onPressed: () =>
                                  adminVM.markMessageRead(m['id']),
                              icon: const Icon(
                                  Icons.done_all_rounded,
                                  size: 16),
                              label: const Text('Mark as Read'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatThreadScreen(
                                  messageId:   m['id'],
                                  reportId:    reportId,
                                  workerId:    m['workerId'] as String? ?? '',
                                  isAdminView: true,
                                ),
                              ),
                            ),
                            icon: const Icon(
                                Icons.reply_rounded,
                                size: 16),
                            label: const Text('Reply'),
                            style: TextButton.styleFrom(
                              foregroundColor: _kGreen,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Dialogs & Sheets ──────────────────────────────────────────────────────────

  Future<void> _confirmLogout(AuthViewModel authVM) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) authVM.logout();
  }

  Future<void> _confirmDeleteUser(
      AdminDashboardViewModel adminVM, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User'),
        content: const Text('This cannot be undone. Delete this user?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await adminVM.deleteUser(userId);
      if (mounted) _showSnack('User deleted');
    }
  }

  Future<void> _confirmDeleteWorker(
      AdminDashboardViewModel adminVM, String workerId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Worker'),
        content: const Text('Remove this worker from the system?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await adminVM.deleteWorker(workerId);
  }

  void _showEditUserSheet(
      AdminDashboardViewModel adminVM, Map<String, dynamic> user) {
    final nameCtrl  = TextEditingController(text: user['name']  ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit User',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
                controller: nameCtrl,
                decoration:
                _inputDec('Full Name', Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: _inputDec('Phone', Icons.phone_outlined),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await adminVM.updateUser(user['id'], {
                    'name':  nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                  });
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWorkerSheet(AdminDashboardViewModel adminVM) {
    final nameCtrl    = TextEditingController();
    final phoneCtrl   = TextEditingController();
    final emailCtrl   = TextEditingController();
    final authUidCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Worker',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                  controller: nameCtrl,
                  decoration:
                  _inputDec('Full Name', Icons.person_outline)),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: _inputDec('Email', Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: _inputDec('Phone', Icons.phone_outlined),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authUidCtrl,
                decoration: _inputDec(
                    'Firebase Auth UID (optional)',
                    Icons.key_outlined),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the worker\'s Firebase Auth UID so they can log in and see assigned tasks.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final data = {
                      'name':  nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'role':  'worker',
                    };
                    if (authUidCtrl.text.trim().isNotEmpty) {
                      data['authUid'] = authUidCtrl.text.trim();
                    }
                    await adminVM.addWorker(data);
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add Worker'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: _kBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _emptyState(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined, size: 52, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(msg,
            style: TextStyle(color: Colors.grey[500], fontSize: 15)),
      ],
    ),
  );

  BoxDecoration _cardDec() => BoxDecoration(
    color: _kCard,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3))
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Admin Report Tile
// ─────────────────────────────────────────────────────────────────────────────
class _AdminReportTile extends StatelessWidget {
  const _AdminReportTile({
    required this.report,
    required this.workers,
    required this.onAssign,
  });
  final ComplaintModel             report;
  final List<Map<String, dynamic>> workers;
  final void Function(String, String) onAssign;

  @override
  Widget build(BuildContext context) {
    final isEscalated = report.status.toUpperCase() == 'ESCALATED';
    final isHigh      = report.priority.toLowerCase() == 'high';

    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailAdminScreen(
              report:   report,
              workers:  workers,
              onAssign: onAssign,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isEscalated
                    ? _kRed
                    : isHigh
                    ? _kOrange
                    : _kGreen,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isEscalated) _badge('⚠ ESCALATED', _kRed)
                  else if (isHigh) _badge('HIGH PRIORITY', _kOrange),
                  const Spacer(),
                  _StatusChip(status: report.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(report.category,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address.isNotEmpty ? report.address : 'No address',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (report.assignedWorkerName == null)
                    _AssignButton(workers: workers, onAssign: onAssign)
                  else
                    Row(children: [
                      const Icon(Icons.engineering,
                          size: 14, color: _kBlue),
                      const SizedBox(width: 4),
                      Text(report.assignedWorkerName!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _kBlue,
                              fontWeight: FontWeight.w600)),
                    ]),
                  const Spacer(),
                  if (report.timestamp != null)
                    Text(_timeAgo(report.timestamp!.toDate()),
                        style:
                        TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    return '${d.inMinutes}m ago';
  }
}

class _AssignButton extends StatelessWidget {
  const _AssignButton({required this.workers, required this.onAssign});
  final List<Map<String, dynamic>> workers;
  final void Function(String, String) onAssign;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kGreenSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_rounded, size: 14, color: _kGreen),
            SizedBox(width: 5),
            Text('Assign Worker',
                style: TextStyle(
                    fontSize: 12,
                    color: _kGreen,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No workers available')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Worker',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ...workers.map((w) => ListTile(
            leading: CircleAvatar(
              backgroundColor: _kGreenSurface,
              child: Text(
                  (w['name'] as String? ?? 'W')[0].toUpperCase(),
                  style: const TextStyle(
                      color: _kGreen, fontWeight: FontWeight.bold)),
            ),
            title:    Text(w['name'] ?? 'Unknown'),
            subtitle: Text(w['phone'] ?? ''),
            onTap: () {
              Navigator.pop(context);
              onAssign(
                  (w['effectiveAuthUid'] ?? w['id']) as String,
                  w['name'] as String? ?? 'Worker');
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  User & Worker Tiles
// ─────────────────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  const _UserTile(
      {required this.user, required this.onDelete, required this.onEdit});
  final Map<String, dynamic> user;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name  = user['name']  as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final role  = user['role']  as String? ?? 'citizen';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _kGreenSurface,
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(
                    color: _kGreen, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(email,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kGreenSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(role.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          color: _kGreen,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: _kGreen),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: _kRed),
              onPressed: onDelete),
        ],
      ),
    );
  }
}

class _WorkerManageTile extends StatelessWidget {
  const _WorkerManageTile(
      {required this.worker, required this.onDelete});
  final Map<String, dynamic> worker;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name   = worker['name']  as String? ?? 'Worker';
    final email  = worker['email'] as String? ?? '';
    final phone  = worker['phone'] as String? ?? '';
    final hasUid =
        (worker['authUid'] as String?)?.isNotEmpty ?? false;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blue[50],
            child: Text(name[0].toUpperCase(),
                style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 6),
                    if (hasUid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _kGreenSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('✓ Linked',
                            style: TextStyle(
                                fontSize: 9,
                                color: _kGreen,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                if (email.isNotEmpty)
                  Text(email,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: _kRed),
              onPressed: onDelete),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final int    value;
  final Color  color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value.toString(),
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.8), fontSize: 11)),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color get _c {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return _kGreen;
      case 'IN_PROGRESS': return _kBlue;
      case 'ASSIGNED':    return Colors.blue[600]!;
      case 'ESCALATED':   return _kRed;
      default:            return _kOrange;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _c.withValues(alpha: 0.3)),
    ),
    child: Text(status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
            color: _c, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color, this.count);
  final String label;
  final Color  color;
  final int    count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child:
            Text(label, style: const TextStyle(fontSize: 12))),
        Text(count.toString(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.label, this.value, this.icon, this.color);
  final String   label;
  final int      value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value.toString(),
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color.withValues(alpha: 0.8))),
      ],
    ),
  );
}