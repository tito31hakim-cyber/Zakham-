import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';

/// Arabic labels for server order/payment statuses.
String orderStatusLabel(String status) => switch (status) {
      'pending_transfer' => 'بانتظار التحويل',
      'paid' => 'مدفوع',
      'processing' => 'قيد التجهيز',
      'shipped' => 'تم الشحن',
      'delivered' => 'تم التوصيل',
      'cancelled' => 'ملغي',
      _ => status,
    };

String paymentStatusLabel(String status) => switch (status) {
      'unpaid' => 'غير مدفوع',
      'proof_submitted' => 'تم إرسال الإثبات',
      'verified' => 'تم التحقق',
      'rejected' => 'مرفوض',
      'refunded' => 'مسترد',
      _ => status,
    };

/// Allowed next order statuses, exactly as the server enforces them.
const Map<String, List<String>> _nextStatuses = {
  'pending_transfer': ['paid', 'cancelled'],
  'paid': ['processing', 'cancelled'],
  'processing': ['shipped', 'cancelled'],
  'shipped': ['delivered'],
  'delivered': [],
  'cancelled': ['pending_transfer'],
};

const Map<String, String> _statusActionLabel = {
  'paid': 'تأكيد الدفع',
  'processing': 'بدء التجهيز',
  'shipped': 'تم الشحن',
  'delivered': 'تم التوصيل',
  'cancelled': 'إلغاء الطلب',
  'pending_transfer': 'إعادة فتح الطلب',
};

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final totp = TextEditingController();
  bool loading = false;
  bool totpRequired = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    totp.dispose();
    super.dispose();
  }

  Future<void> open() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'أدخل البريد وكلمة المرور.');
      return;
    }
    if (totpRequired && totp.text.trim().isEmpty) {
      setState(() => error = 'أدخل رمز التحقق الثنائي من تطبيق المصادقة.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = AdminApi();
      await api.login(
        email: email.text.trim(),
        password: password.text,
        totp: totpRequired ? totp.text.trim() : null,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboardPage(api: api)),
        );
      }
    } on TotpRequiredException {
      if (mounted) {
        setState(() {
          totpRequired = true;
          error = 'هذا الحساب محمي برمز تحقق ثنائي — أدخل الرمز من تطبيق المصادقة.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
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
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              color: gold,
              size: 70,
            ),
            const SizedBox(height: 18),
            const Text(
              'لوحة إدارة دار زخم',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سجّل الدخول ببريد الإدارة وكلمة المرور — نفس حساب لوحة تحكم الموقع.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'بريد الإدارة',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (totpRequired) ...[
              const SizedBox(height: 14),
              TextField(
                controller: totp,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق الثنائي',
                  prefixIcon: Icon(Icons.security_outlined),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: loading ? null : open,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('دخول آمن'),
            ),
          ],
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

  Future<void> _logout() async {
    await widget.api.logout();
    if (mounted) Navigator.pop(context);
  }

  String _money(dynamic value) {
    if (value is num) return '${value.toStringAsFixed(0)} ج.م';
    return '—';
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
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: Column(
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: stats,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(color: gold),
                  );
                }
                final data = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('الطلبات', '${data['orders'] ?? '—'}'),
                      _stat('الإيرادات', _money(data['revenue'])),
                      _stat('بانتظار الدفع', '${data['pending'] ?? '—'}'),
                      _stat('تم التوصيل', '${data['delivered'] ?? '—'}'),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  _ProductsPanel(api: widget.api),
                  _CustomersPanel(api: widget.api),
                  _OrdersPanel(api: widget.api),
                  _PushPanel(api: widget.api),
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
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              label: 'إشعارات',
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
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

  /// مخزون المنتج كما يرده الخادم الإداري.
  ///
  /// تنبيه أمني (2026-11-17): نقطة `/api/admin/products` تشارك نفس
  /// مسلسل `productRow` مع واجهة المتجر العامة، فبعد إزالة حقول الأصالة
  /// والمخزون الدقيق من الرد العام لم يعد الرد الإداري يحمل `stockQty`
  /// ولا `codePrefix`/`codeNumber`/`bottleLabel`. إن حُفظ تعديلٌ والقيم
  /// مفقودة فسيكتب الخادم (PATCH) مخزون 0 وحالة «غير متوفر» ويمسح كود
  /// الأصالة — لذلك يُمنع الحفظ أدناه عند غياب هذه الحقول، ويُشتق
  /// المخزون للعرض من `variantRows` (ترد من استعلام منفصل لم يُمس).
  static int? _adminStock(Map<String, dynamic> p) {
    final direct = p['stockQty'];
    if (direct is num) return direct.toInt();
    if (direct is String) return int.tryParse(direct.trim());
    final rows = p['variantRows'];
    if (rows is List) {
      var total = 0;
      var found = false;
      for (final row in rows) {
        if (row is! Map) continue;
        final active = row['is_active'];
        if (active == 0 || active == false || active == '0') continue;
        final qty = row['stock_qty'];
        if (qty is num) {
          total += qty.toInt();
          found = true;
        } else if (qty is String) {
          final parsed = int.tryParse(qty.trim());
          if (parsed != null) {
            total += parsed;
            found = true;
          }
        }
      }
      if (found) return total;
    }
    return null;
  }

  /// هل تحمل بيانات المنتج الحقول الإدارية اللازمة لحفظ آمن؟
  /// غيابها يعني أن PATCH سيمسح المخزون وكود الأصالة — فيُمنع الحفظ.
  static bool _hasAdminFields(Map<String, dynamic> p) =>
      p.containsKey('codePrefix') &&
      p.containsKey('codeNumber') &&
      p.containsKey('bottleLabel') &&
      (p.containsKey('stockQty') || _adminStock(p) != null);

  Future<void> _edit(Map<String, dynamic> p) async {
    if (!_hasAdminFields(p)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن تعديل هذا المنتج حالياً — الخادم لا يرسل حقول المخزون وكود الأصالة الإدارية، والحفظ الآن سيمسحها. أصلح الخادم أولاً.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
      return;
    }
    final stockValue = _adminStock(p) ?? 0;
    final name = TextEditingController(text: '${p['name'] ?? ''}');
    final stock = TextEditingController(text: '$stockValue');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر الحفظ: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر الإخفاء: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'تعذر تحميل المنتجات: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: gold));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              setState(() => future = widget.api.products()),
          child: ListView.builder(
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
                    // المخزون من الرد الإداري مباشرةً، أو من variantRows،
                    // أو «—» عند غيابهما — لا يُعرض 0 زائفاً أبداً.
                    'المخزون: ${_adminStock(product)?.toString() ?? '—'} · ${product['stockStatus'] ?? ''}',
                    style: const TextStyle(color: muted),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'edit' ? _edit(product) : _delete(product),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('إخفاء المنتج'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CustomersPanel extends StatefulWidget {
  const _CustomersPanel({required this.api});
  final AdminApi api;
  @override
  State<_CustomersPanel> createState() => _CustomersPanelState();
}

class _CustomersPanelState extends State<_CustomersPanel> {
  final search = TextEditingController();
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.customers();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _runSearch() =>
      setState(() => future = widget.api.customers(search.text.trim()));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            controller: search,
            decoration: InputDecoration(
              labelText: 'ابحث بالاسم أو البريد',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  search.clear();
                  _runSearch();
                },
              ),
            ),
            onSubmitted: (_) => _runSearch(),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: future,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'تعذر تحميل العملاء: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: gold),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('لا يوجد عملاء مطابقون.', style: TextStyle(color: muted)),
                );
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (_, index) {
                  final customer =
                      Map<String, dynamic>.from(snapshot.data![index]);
                  return Card(
                    color: card,
                    child: ListTile(
                      title: Text(
                        '${customer['displayName'] ?? ''}',
                        style: const TextStyle(color: cream),
                      ),
                      subtitle: Text(
                        '${customer['email'] ?? ''} · طلبات: ${customer['ordersCount'] ?? 0}',
                        style: const TextStyle(color: muted),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrdersPanel extends StatefulWidget {
  const _OrdersPanel({required this.api});
  final AdminApi api;
  @override
  State<_OrdersPanel> createState() => _OrdersPanelState();
}

class _OrdersPanelState extends State<_OrdersPanel> {
  String status = '';
  int page = 1;
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      setState(() => future = widget.api.orders(status: status, page: page));

  void _pickStatus(String next) {
    status = next;
    page = 1;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'تعذر تحميل الطلبات: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: gold));
        }
        final data = snapshot.data!;
        final orders = (data['orders'] as List?) ?? [];
        final buckets =
            (data['bucketCounts'] as Map?)?.cast<String, dynamic>() ?? {};
        final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _chip('الكل', '', buckets['all']),
                  _chip('بانتظار التحويل', 'pending_transfer', buckets['waiting_payment']),
                  _chip('مدفوع', 'paid', null),
                  _chip('قيد التجهيز', 'processing', null),
                  _chip('تم الشحن', 'shipped', null),
                  _chip('تم التوصيل', 'delivered', buckets['completed']),
                  _chip('ملغي', 'cancelled', buckets['archive']),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد طلبات في هذا التصنيف.',
                        style: TextStyle(color: muted),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: ListView.builder(
                        itemCount: orders.length,
                        itemBuilder: (_, index) {
                          final order =
                              Map<String, dynamic>.from(orders[index]);
                          final ref = '${order['order_ref'] ?? ''}';
                          return Card(
                            color: card,
                            child: ListTile(
                              title: Text(
                                ref,
                                style: const TextStyle(color: cream),
                              ),
                              subtitle: Text(
                                '${order['created_at'] ?? ''} · ${order['governorate'] ?? ''} · ${orderStatusLabel('${order['status'] ?? ''}')} · ${paymentStatusLabel('${order['payment_status'] ?? ''}')}',
                                style: const TextStyle(color: muted),
                              ),
                              trailing: Text(
                                '${order['total'] ?? ''} ج.م',
                                style: const TextStyle(
                                  color: gold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _OrderDetailPage(
                                      api: widget.api,
                                      ref: ref,
                                    ),
                                  ),
                                );
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      onPressed: page > 1
                          ? () {
                              page--;
                              _load();
                            }
                          : null,
                    ),
                    Text('صفحة $page من $totalPages',
                        style: const TextStyle(color: muted)),
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      onPressed: page < totalPages
                          ? () {
                              page++;
                              _load();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, String value, dynamic count) {
    final selected = status == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(
          count is num ? '$label ($count)' : label,
          style: TextStyle(color: selected ? Colors.black : cream),
        ),
        selected: selected,
        selectedColor: gold,
        backgroundColor: card,
        onSelected: (_) => _pickStatus(value),
      ),
    );
  }
}

class _OrderDetailPage extends StatefulWidget {
  const _OrderDetailPage({required this.api, required this.ref});
  final AdminApi api;
  final String ref;
  @override
  State<_OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<_OrderDetailPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.orderDetail(widget.ref);
  }

  void _reload() => setState(() => future = widget.api.orderDetail(widget.ref));

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Asks for a reason. Returns null when the admin cancels the dialog.
  Future<String?> _askReason({
    required String title,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: required ? 'السبب (إلزامي)' : 'السبب (اختياري)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    if (required && result.length < 5) {
      _snack('اكتب سبباً واضحاً (5 أحرف على الأقل).');
      return null;
    }
    return result;
  }

  Future<void> _changeStatus(String current, String next) async {
    var reason = '';
    if (next == 'cancelled') {
      final asked = await _askReason(
        title: 'سبب إلغاء الطلب',
        required: true,
      );
      if (asked == null) return;
      reason = asked;
    }
    try {
      await widget.api.updateOrderStatus(widget.ref, next, reason: reason);
      _snack('تم تحديث حالة الطلب إلى «${orderStatusLabel(next)}».');
      _reload();
    } catch (e) {
      _snack('تعذر التحديث: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _verifyPayment(bool receiptAvailable) async {
    var reason = '';
    var manual = false;
    if (!receiptAvailable) {
      final asked = await _askReason(
        title: 'تأكيد الدفع يدوياً (لا يوجد إثبات مرفوع)',
        required: true,
      );
      if (asked == null) return;
      reason = asked;
      manual = true;
    }
    try {
      await widget.api.updatePaymentStatus(
        widget.ref,
        'verified',
        reason: reason,
        manualConfirmation: manual,
      );
      _snack('تم تأكيد الدفع.');
      _reload();
    } catch (e) {
      _snack('تعذر تأكيد الدفع: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _rejectPayment() async {
    final reason = await _askReason(title: 'سبب رفض الدفع', required: true);
    if (reason == null) return;
    try {
      await widget.api.updatePaymentStatus(
        widget.ref,
        'rejected',
        reason: reason,
      );
      _snack('تم رفض الدفع.');
      _reload();
    } catch (e) {
      _snack('تعذر رفض الدفع: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _refundPayment() async {
    final reason = await _askReason(title: 'سبب الاسترداد', required: true);
    if (reason == null) return;
    try {
      await widget.api.updatePaymentStatus(
        widget.ref,
        'refunded',
        reason: reason,
      );
      _snack('تم تسجيل الاسترداد.');
      _reload();
    } catch (e) {
      _snack('تعذر الاسترداد: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.ref)),
        body: FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل الطلب: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: gold),
              );
            }
            final order = Map<String, dynamic>.from(
              (snapshot.data!['order'] as Map?) ?? {},
            );
            final items = (order['items'] as List?) ?? [];
            final history = (snapshot.data!['history'] as List?) ?? [];
            final status = '${order['status'] ?? ''}';
            final paymentStatus = '${order['paymentStatus'] ?? ''}';
            final receiptAvailable = order['receiptAvailable'] == true;
            final next = _nextStatuses[status] ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('الطلب', [
                  _row('الحالة', orderStatusLabel(status)),
                  _row('الدفع', paymentStatusLabel(paymentStatus)),
                  _row('التاريخ', '${order['createdAt'] ?? ''}'),
                  _row('طريقة الدفع', '${order['paymentMethod'] ?? ''}'),
                  if ((order['receiptReference'] as String?)?.isNotEmpty == true)
                    _row('مرجع الإيصال', '${order['receiptReference']}'),
                  if ((order['notes'] as String?)?.isNotEmpty == true)
                    _row('ملاحظات', '${order['notes']}'),
                ]),
                _section('العميل', [
                  _row('الاسم', '${order['customerName'] ?? ''}'),
                  _row('الهاتف', '${order['phone'] ?? ''}'),
                  _row('المحافظة', '${order['governorate'] ?? ''}'),
                  if ((order['city'] as String?)?.isNotEmpty == true)
                    _row('المدينة', '${order['city']}'),
                  _row('العنوان', '${order['address'] ?? ''}'),
                ]),
                _section(
                  'الأصناف',
                  items.map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    return _row(
                      '${item['nameAr'] ?? ''} — ${item['sizeMl'] ?? ''} مل (${item['concentration'] ?? ''}) × ${item['quantity'] ?? 1}',
                      '${item['lineTotal'] ?? ''} ج.م',
                    );
                  }).toList(),
                ),
                _section('المبالغ', [
                  _row('المجموع الفرعي', '${order['subtotal'] ?? ''} ج.م'),
                  _row('الشحن', '${order['shippingFee'] ?? ''} ج.م'),
                  if ((order['discountAmount'] as num?) != null &&
                      (order['discountAmount'] as num) > 0)
                    _row('الخصم', '-${order['discountAmount']} ج.م'),
                  _row('الإجمالي', '${order['total'] ?? ''} ج.م'),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'تغيير حالة الطلب',
                  style: TextStyle(
                    color: cream,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: next.isEmpty
                      ? [
                          const Text(
                            'لا توجد انتقالات متاحة من هذه الحالة.',
                            style: TextStyle(color: muted),
                          ),
                        ]
                      : next
                          .map(
                            (target) => FilledButton(
                              onPressed: () => _changeStatus(status, target),
                              child: Text(
                                _statusActionLabel[target] ?? target,
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'مراجعة الدفع',
                  style: TextStyle(
                    color: cream,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (paymentStatus == 'proof_submitted') ...[
                      FilledButton(
                        onPressed: () => _verifyPayment(receiptAvailable),
                        child: const Text('تأكيد الدفع'),
                      ),
                      OutlinedButton(
                        onPressed: _rejectPayment,
                        child: const Text('رفض الدفع'),
                      ),
                    ] else if (paymentStatus == 'unpaid') ...[
                      FilledButton(
                        onPressed: () => _verifyPayment(false),
                        child: const Text('تأكيد دفع يدوي'),
                      ),
                    ] else if (paymentStatus == 'verified') ...[
                      OutlinedButton(
                        onPressed: _refundPayment,
                        child: const Text('تسجيل استرداد'),
                      ),
                    ] else
                      const Text(
                        'لا توجد إجراءات دفع متاحة لهذه الحالة.',
                        style: TextStyle(color: muted),
                      ),
                  ],
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'سجل الطلب',
                    style: TextStyle(
                      color: cream,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...history.map((raw) {
                    final event = Map<String, dynamic>.from(raw as Map);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${event['createdAt'] ?? ''} · ${event['eventType'] ?? ''}: ${event['oldValue'] ?? ''} ← ${event['newValue'] ?? ''}${(event['reason'] as String?)?.isNotEmpty == true ? ' — ${event['reason']}' : ''}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        color: card,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: muted)),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: cream),
              ),
            ),
          ],
        ),
      );
}

/// Sends push notifications to customers through the store server
/// (POST /api/admin/push/send). The audience is one FCM topic, or "all"
/// which sends to every topic one by one. Until the server endpoint is
/// deployed the call answers 404 and a clear message is shown.
class _PushPanel extends StatefulWidget {
  const _PushPanel({required this.api});
  final AdminApi api;
  @override
  State<_PushPanel> createState() => _PushPanelState();
}

class _PushPanelState extends State<_PushPanel> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'all';
  bool _sending = false;
  String? _result;

  static const Map<String, String> _audiences = {
    'all': 'الكل — كل المشتركين',
    PushService.topicOrders: 'تحديثات الطلبات',
    PushService.topicOffers: 'العروض والخصومات',
    PushService.topicNewArrivals: 'وصل حديثاً',
  };

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _result = 'اكتب عنوان الإشعار ونصه أولاً.');
      return;
    }
    setState(() {
      _sending = true;
      _result = null;
    });
    final topics = _audience == 'all'
        ? <String>[
            PushService.topicOrders,
            PushService.topicOffers,
            PushService.topicNewArrivals,
          ]
        : <String>[_audience];
    var sent = 0;
    var failure = '';
    for (final topic in topics) {
      try {
        await widget.api.sendPush(title: title, body: body, topic: topic);
        sent++;
      } catch (error) {
        failure = error.toString().replaceFirst('Exception: ', '');
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = failure.isNotEmpty
          ? failure
          : 'تم إرسال الإشعار إلى $sent ${sent == 1 ? 'موضوع' : 'مواضيع'} بنجاح.';
    });
    if (failure.isEmpty) {
      _title.clear();
      _body.clear();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'إرسال إشعار للعملاء',
            style: TextStyle(
              color: cream,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'يصل الإشعار إلى التطبيق عبر Firebase — للمشتركين في الموضوع المختار فقط.',
            style: TextStyle(color: muted, height: 1.6),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'عنوان الإشعار',
              hintText: 'مثال: وصل حديثاً — تشكيلة 2027',
              prefixIcon: Icon(Icons.title_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'نص الإشعار',
              hintText: 'اكتب رسالتك للعملاء...',
              prefixIcon: Icon(Icons.message_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _audience,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الجمهور',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
            items: _audiences.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _audience = value);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال الإشعار'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: gold.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withOpacity(.24)),
              ),
              child: Text(
                _result!,
                style: const TextStyle(color: cream, height: 1.6),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'ملحوظة: نقطة الإرسال على الخادم تُنشر بشكل منفصل — إن ظهرت رسالة 404 فالإرسال لم يُفعَّل بعد.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.6),
          ),
        ],
      );
}
