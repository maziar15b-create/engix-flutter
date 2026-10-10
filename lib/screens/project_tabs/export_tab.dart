import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/config.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

const _exportBucket = 'project-exports';

const _sectionDefs = <List<String>>[
  ['correspondence', 'نامه‌ها / مکاتبات'],
  ['dailyreport', 'گزارش روزانه'],
  ['reports', 'گزارش کار'],
  ['supervision', 'نظارت'],
  ['gantt', 'برنامه زمان‌بندی'],
  ['workorder', 'دستور کار'],
  ['qc', 'کنترل کیفیت'],
  ['documents', 'دفتر فنی / اسناد'],
  ['inventory', 'انبار'],
  ['attendance', 'حضور و غیاب'],
  ['photos', 'گالری تصاویر'],
  ['announcements', 'اطلاعیهها'],
];

const _dirLabels = {'incoming': 'وارده', 'outgoing': 'صادره'};
const _qcLabels = {'pass': 'قبول', 'fail': 'رد', 'pending': 'در انتظار'};
const _attLabels = {'present': 'حاضر', 'absent': 'غایب', 'half': 'نیمهروز'};
const _woLabels = {'done': 'انجام‌شده', 'pending': 'در انتظار'};
const _invLabels = {'in': 'ورود', 'out': 'خروج'};

String _d(dynamic v) => (v == null || '$v'.isEmpty) ? '—' : faDate(v);
String _v(dynamic v) => (v == null || '$v'.isEmpty) ? '—' : '$v';

class _Section {
  final String key;
  final String label;
  final List<String> headers;
  final List<List<String>> rows;
  _Section(this.key, this.label, this.headers, this.rows);
}

class ExportTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> members;
  const ExportTab(
      {super.key,
      required this.projectId,
      required this.profile,
      required this.project,
      required this.members});
  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  final Set<String> _selected = {for (final s in _sectionDefs) s[0]};
  String _busy = '';
  String _error = '';
  String _notice = '';
  bool _showShare = false;
  final Set<String> _picked = {};
  String? _xlsxUrl;
  String? _htmlUrl;

  Future<List<Map<String, dynamic>>> _q(String table, String order, {bool asc = false}) async {
    final d = await sb.from(table).select().eq('project_id', widget.projectId).order(order, ascending: asc);
    return List<Map<String, dynamic>>.from(d);
  }

  Future<List<_Section>> _buildSections() async {
    if (_selected.isEmpty) throw Exception('حداقل یک بخش را برای خروجی انتخاب کنید.');
    final corr = await _q('project_correspondence', 'correspondence_date');
    final daily = await _q('project_daily_reports', 'report_date');
    final updates = await _q('project_updates', 'created_at');
    final superv = await _q('reports', 'created_at');
    final gantt = await _q('project_gantt_tasks', 'order_index', asc: true);
    final wos = await _q('project_work_orders', 'meeting_date');
    final qc = await _q('project_qc_items', 'order_index', asc: true);
    final docs = await _q('project_documents', 'created_at');
    final inv = await _q('project_inventory_transactions', 'transaction_date');
    final att = await _q('project_attendance', 'attendance_date');
    final photos = await _q('project_phot
