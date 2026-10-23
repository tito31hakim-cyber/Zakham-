import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final token = TextEditingController();
  bool loading = false;
  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  Future<void> open() async {
    if (token.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      final api = AdminApi(token: token.text.trim());
      await api.analytics();
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboardPage(api: api)),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر التحقق: $error')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('دخول الإدارة')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: gold,
                size: 70,
              ),
              const SizedBox(height: 18),
              const Text(
                'لوحة إدارة دار زخم',
                style: TextStyle(
                  color: cream,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: token,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'رمز الإدارة',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: loading ? null : open,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('دخول آمن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int tab = 0;
  late Future<Map<String, dynamic>> stats;
  @override
  void initState() {
    super.initState();
    stats = widget.api.analytics();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الإدارة'),
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Column(
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: stats,
              builder: (_, snapshot) => snapshot.hasData
                  ? _stats(snapshot.data!)
                  : const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(color: gold),
                    ),
            ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  _ProductsPanel(api: widget.api),
                  _CustomersPanel(api: widget.api),
                  const _OrdersPanel(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'المنتجات',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'العملاء',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'الطلبات',
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(Map<String, dynamic> data) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stat('الطلبات', data['orders']),
        _stat('العملاء', data['customers']),
      ],
    ),
  );
  Widget _stat(String label, dynamic value) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: gold,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: muted)),
    ],
  );
}

class _ProductsPanel extends StatefulWidget {
  const _ProductsPanel({required this.api});
  final AdminApi api;
  @override
  State<_ProductsPanel> createState() => _ProductsPanelState();
}

class _ProductsPanelState extends State<_ProductsPanel> {
  late Future<List<dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.api.products();
  }

  Map<String, dynamic> _payload(
    Map<String, dynamic> p,
    String name,
    int stock,
    bool visible,
  ) => {
    'nameAr': name,
    'nameEn': p['en'] ?? '',
    'category': p['category'] ?? '',
    'categoryLabel': p['categoryLabel'] ?? '',
    'season': p['season'] ?? '',
    'occasion': p['occasion'] ?? '',
    'lasting': p['lasting'] ?? '',
    'notes': p['notes'] ?? {},
    'tags': p['tags'] ?? [],
    'prices': p['prices'] ?? {},
    'variants': p['variants'] ?? [],
    'image': p['image'] ?? '',
    'visible': visible,
    'stockQty': stock,
    'stockStatus': stock > 0 ? 'available' : 'out_of_stock',
    'codePrefix': p['codePrefix'] ?? '',
    'codeNumber': p['codeNumber'] ?? '',
    'bottleLabel': p['bottleLabel'] ?? '',
  };

  Future<void> _edit(Map<String, dynamic> p) async {
    final name = TextEditingController(text: '${p['name'] ?? ''}');
    final stock = TextEditingController(text: '${p['stockQty'] ?? 0}');
    var visible = p['visible'] != false;
    final save = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('تعديل المنتج'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم المنتج'),
              ),
              TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المخزون'),
              ),
              SwitchListTile(
                value: visible,
                onChanged: (v) => setDialog(() => visible = v),
                title: const Text('ظاهر في المتجر'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (save != true) {
      name.dispose();
      stock.dispose();
      return;
    }
    try {
      await widget.api.updateProduct(
        id: '${p['id']}',
        product: _payload(
          p,
          name.text.trim(),
          int.tryParse(stock.text) ?? 0,
          visible,
        ),
      );
      if (mounted) {
        setState(() => future = widget.api.products());
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ المنتج')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر الحفظ: $error')));
    }
    name.dispose();
    stock.dispose();
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('إخفاء المنتج؟'),
            content: Text(
              'سيتم إخفاء «${p['name']}» من المتجر دون حذف السجل من قاعدة البيانات.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إخفاء'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await widget.api.deleteProduct('${p['id']}');
      if (mounted) {
        setState(() => future = widget.api.products());
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم إخفاء المنتج')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر الإخفاء: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator(color: gold));
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (_, index) {
            final product = Map<String, dynamic>.from(snapshot.data![index]);
            return Card(
              color: card,
              child: ListTile(
                title: Text(
                  '${product['name'] ?? ''}',
                  style: const TextStyle(color: cream),
                ),
                subtitle: Text(
                  'المخزون: ${product['stockQty'] ?? 0} · ${product['stockStatus'] ?? ''}',
                  style: const TextStyle(color: muted),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) =>
                      value == 'edit' ? _edit(product) : _delete(product),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'delete', child: Text('إخفاء المنتج')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CustomersPanel extends StatelessWidget {
  const _CustomersPanel({required this.api});
  final AdminApi api;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: api.customers(),
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator(color: gold));
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (_, index) {
            final customer = Map<String, dynamic>.from(snapshot.data![index]);
            return Card(
              color: card,
              child: ListTile(
                title: Text(
                  '${customer['displayName'] ?? ''}',
                  style: const TextStyle(color: cream),
                ),
                subtitle: Text(
                  '${customer['email'] ?? ''}',
                  style: const TextStyle(color: muted),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrdersPanel extends StatelessWidget {
  const _OrdersPanel();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'لا يوجد Endpoint إداري للطلبات في api.php الحالي. أضف GET /api/admin/orders وPATCH /api/admin/orders/{orderRef}/status لتمكين هذا القسم.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted),
      ),
    ),
  );
}
