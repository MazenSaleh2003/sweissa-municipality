import 'package:flutter/material.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final List<_StaffCase> _cases = [
    _StaffCase('BL-1042', 'إنارة الشوارع', 'الحي الشرقي', 'جديد', 'منذ 20 دقيقة', 'الصيانة'),
    _StaffCase('BL-1041', 'حفرة في الطريق', 'قرب المدرسة', 'قيد المعالجة', 'منذ ساعتين', 'الأشغال'),
    _StaffCase('SR-209', 'إفادة سكن', 'مكتب البلدية', 'جديد', 'اليوم', 'الإدارة'),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة فريق البلدية', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StaffAnalyticsPage()),
              ),
              icon: const Icon(Icons.bar_chart_outlined),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('مرحباً، فريق السويسة', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text('ملخص الطلبات والخدمات اليوم', style: TextStyle(color: Color(0xFF65716F))),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _metric('12', 'بلاغ جديد', const Color(0xFFFFE9D7), Icons.notifications_active_outlined),
                  _metric('8', 'قيد المعالجة', const Color(0xFFE8EEF9), Icons.engineering_outlined),
                  _metric('24', 'تم الحل هذا الأسبوع', const Color(0xFFDDEFEA), Icons.check_circle_outline),
                  _metric('3', 'طلبات خدمة جديدة', const Color(0xFFF5E6F6), Icons.description_outlined),
                ],
              ),
              const SizedBox(height: 28),
              const Text('أحدث الطلبات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._cases.map(_caseCard),
              const SizedBox(height: 10),
              const Text('هذه بيانات تجريبية. عند ربط حسابات الموظفين وقاعدة البيانات ستظهر الطلبات الحقيقية هنا.', style: TextStyle(color: Color(0xFF65716F), fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String number, String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF0A6257)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 12))])),
        ]),
      );

  Widget _caseCard(_StaffCase item) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(item.id, style: const TextStyle(color: Color(0xFF65716F), fontWeight: FontWeight.w600)),
            const Spacer(),
            DropdownButton<String>(
              value: item.status,
              underline: const SizedBox(),
              items: const ['جديد', 'قيد المعالجة', 'تم الحل'].map((value) => DropdownMenuItem(value: value, child: Text(value, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (value) => setState(() => item.status = value!),
            ),
          ]),
          const SizedBox(height: 5),
          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.location_on_outlined, size: 17, color: Color(0xFF65716F)), const SizedBox(width: 4), Text(item.location, style: const TextStyle(color: Color(0xFF65716F))), const Spacer(), Text(item.time, style: const TextStyle(color: Color(0xFF65716F), fontSize: 12))]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.group_work_outlined, size: 17, color: Color(0xFF65716F)),
            const SizedBox(width: 5),
            const Text('القسم:', style: TextStyle(color: Color(0xFF65716F))),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: item.department,
              underline: const SizedBox(),
              items: const ['الصيانة', 'الأشغال', 'النظافة', 'الإدارة'].map((value) => DropdownMenuItem(value: value, child: Text(value, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (value) => setState(() => item.department = value!),
            ),
          ]),
        ]),
      );
}

class _StaffCase {
  _StaffCase(this.id, this.title, this.location, this.status, this.time, this.department);

  final String id;
  final String title;
  final String location;
  String status;
  final String time;
  String department;
}

class StaffAnalyticsPage extends StatelessWidget {
  const StaffAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحليلات البلدية', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('أداء هذا الشهر', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _summary('4.2 ساعة', 'متوسط أول رد', Icons.timer_outlined, const Color(0xFFE8EEF9))),
              const SizedBox(width: 12),
              Expanded(child: _summary('78%', 'نسبة الحل', Icons.check_circle_outline, const Color(0xFFDDEFEA))),
            ]),
            const SizedBox(height: 26),
            const Text('البلاغات حسب الفئة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            _bar('إنارة الشوارع', 18, 0.90, const Color(0xFF0A6257)),
            _bar('الطرق والحفر', 14, 0.70, const Color(0xFFD99E32)),
            _bar('النفايات', 10, 0.50, const Color(0xFFB54708)),
            _bar('المياه', 6, 0.30, const Color(0xFF5D82C4)),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFFF0D7), borderRadius: BorderRadius.circular(16)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF9A4A10)),
                SizedBox(width: 10),
                Expanded(child: Text('الأولوية المقترحة: ركّزوا على إنارة الشوارع، فهي الفئة الأكثر وروداً هذا الشهر.', style: TextStyle(height: 1.4))),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('البيانات المعروضة تجريبية. ستُحسب تلقائياً من البلاغات الحقيقية بعد تفعيل حسابات الموظفين.', style: TextStyle(color: Color(0xFF65716F), fontSize: 12), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _summary(String value, String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF0A6257)),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      );

  Widget _bar(String label, int count, double value, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), const Spacer(), Text('$count بلاغاً', style: const TextStyle(color: Color(0xFF65716F)))]),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: value, minHeight: 10, borderRadius: BorderRadius.circular(10), color: color, backgroundColor: const Color(0xFFE4EFEA)),
        ]),
      );
}
