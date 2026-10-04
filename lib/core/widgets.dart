import 'package:flutter/material.dart';
import 'repository.dart';
import 'draft_store.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.drafts,
    required super.child,
  });
  final MunicipalityRepository repository;
  final DraftStore drafts;
  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;
  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository || drafts != oldWidget.drafts;
}

void showError(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(friendlyError(error))));
void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      EmptyState(friendlyError(error), icon: Icons.cloud_off_outlined),
      FilledButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
        label: const Text('إعادة المحاولة'),
      ),
    ],
  );
}

class DataView<T> extends StatefulWidget {
  const DataView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback) builder;
  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  late Future<T> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _reload() => setState(() => _future = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return Center(
          child: ErrorState(error: s.error!, retry: _reload),
        );
      }
      return widget.builder(context, s.data as T, _reload);
    },
  );
}

class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.load,
    required this.item,
    required this.empty,
  });
  final Future<List<Map<String, dynamic>>> Function(int offset) load;
  final Widget Function(Map<String, dynamic>, VoidCallback refresh) item;
  final String empty;
  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> {
  final List<Map<String, dynamic>> _rows = [];
  Object? _error;
  bool _busy = false, _more = true;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      if (reset) {
        _rows.clear();
        _offset = 0;
        _more = true;
      }
    });
    try {
      final rows = await widget.load(_offset);
      if (!mounted) return;
      setState(() {
        _offset += rows.length;
        _more = rows.length == 30;
        final ids = _rows.map((r) => r['id']).toSet();
        _rows.addAll(rows.where((r) => ids.add(r['id'])));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => _load(reset: true),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_rows.isEmpty && !_busy && _error == null) EmptyState(widget.empty),
        ..._rows.map((row) => widget.item(row, () => _load(reset: true))),
        if (_error != null) ErrorState(error: _error!, retry: () => _load()),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_busy && _more && _error == null)
          TextButton(onPressed: () => _load(), child: const Text('عرض المزيد')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ) ??
    false;
