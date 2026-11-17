import 'package:flutter/material.dart';

import '../services/invoice_pdf.dart';

/// ودجت فاتورة الطلب — يُعرض في نافذة الفاتورة ويُرسَم في PDF.
///
/// خلفية بيضاء وألوان صريحة (أسود وذهبي داكن) لأن الودجت يُلتقط صورة
/// خارج الشاشة لمستند PDF — لا يعتمد على ثيم التطبيق الحالي.
class InvoiceDocument extends StatelessWidget {
  const InvoiceDocument({super.key, required this.invoice});

  final OrderInvoice invoice;

  static const _ink = Color(0xFF1A1A1A);
  static const _muted = Color(0xFF6B6257);
  static const _gold = Color(0xFF8B5D15);
  static const _goldLine = Color(0xFFC9A45C);
  static const _rowBg = Color(0xFFF7F1E3);

  String _money(double value) {
    final rounded = value.round();
    if (value == rounded.toDouble()) return '$rounded ج.م';
    return '${value.toStringAsFixed(2)} ج.م';
  }

  @override
  Widget build(BuildContext context) {
    final invoice = this.invoice;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'دار زخم للعطور',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'HOUSE OF ZAKHAM',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: _gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'zakhamhouse.shop',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'فاتورة مبدئية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _goldLine,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    invoice.orderRef,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    invoice.createdAt,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 2, color: _goldLine),
          const SizedBox(height: 16),
          _sectionTitle('بيانات العميل'),
          const SizedBox(height: 6),
          _infoRow('الاسم', invoice.customerName),
          _infoRow('الهاتف', invoice.phone),
          _infoRow(
            'المحافظة',
            invoice.city.isEmpty
                ? invoice.governorate
                : '${invoice.governorate} — ${invoice.city}',
          ),
          _infoRow('العنوان', invoice.address),
          const SizedBox(height: 18),
          _sectionTitle('الأصناف'),
          const SizedBox(height: 6),
          Container(
            color: _rowBg,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'العطر',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: Text(
                    'الكمية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    'الإجمالي',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...invoice.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nameAr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        Text(
                          '${item.sizeMl} مل — ${item.concentrationLabel} · ${_money(item.unitPrice)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '×${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: _ink),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(
                      _money(item.lineTotal),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: _goldLine),
          const SizedBox(height: 8),
          _totalRow('المجموع الفرعي', _money(invoice.subtotal)),
          if (invoice.discountAmount > 0)
            _totalRow(
              'خصم كود${invoice.discountCode.isEmpty ? '' : ' (${invoice.discountCode})'}',
              '− ${_money(invoice.discountAmount)}',
            ),
          if (invoice.bundleDiscount > 0)
            _totalRow(
              'خصم عروض الحزم',
              '− ${_money(invoice.bundleDiscount)}',
            ),
          if (invoice.extraDiscount > 0)
            _totalRow(
              'خصم إضافي (نقاط الولاء)',
              '− ${_money(invoice.extraDiscount)}',
            ),
          _totalRow('الشحن', _money(invoice.shippingFee)),
          const SizedBox(height: 6),
          Container(
            color: _ink,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'الإجمالي',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  _money(invoice.total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _goldLine,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _infoRow('طريقة الدفع', invoice.paymentMethod),
          _infoRow('حالة السداد', 'مدفوع'),
          const SizedBox(height: 20),
          const Text(
            'شكراً لثقتكم بدار زخم — صُنع في مصر.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: _gold,
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(fontSize: 13, color: _ink),
              ),
            ),
          ],
        ),
      );

  Widget _totalRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: _ink),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ],
        ),
      );
}
