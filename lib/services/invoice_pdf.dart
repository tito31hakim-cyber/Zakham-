import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';
import '../widgets/invoice_document.dart';

/// صنف في فاتورة طلب (من `orderDto` على الخادم).
class InvoiceItem {
  const InvoiceItem({
    required this.productId,
    required this.nameAr,
    required this.sizeMl,
    required this.concentration,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productId;
  final String nameAr;
  final int sizeMl;
  final String concentration;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  String get concentrationLabel =>
      Product.concentrationNamesAr[concentration] ?? concentration;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        productId: '${json['productId'] ?? ''}',
        nameAr: '${json['nameAr'] ?? ''}',
        sizeMl: (json['sizeMl'] as num?)?.toInt() ?? 0,
        concentration: '${json['concentration'] ?? ''}',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      );
}

/// فاتورة طلب كاملة (من GET /api/orders/{ref}/invoice — الرد `orderDto`).
///
/// تُستخدم لتنزيل/مشاركة فاتورة PDF بعد الدفع فقط.
class OrderInvoice {
  const OrderInvoice({
    required this.orderRef,
    required this.createdAt,
    required this.customerName,
    required this.phone,
    required this.governorate,
    required this.city,
    required this.address,
    required this.paymentMethod,
    required this.subtotal,
    required this.shippingFee,
    required this.discountAmount,
    required this.discountCode,
    required this.bundleDiscount,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.items,
  });

  final String orderRef;
  final String createdAt;
  final String customerName;
  final String phone;
  final String governorate;
  final String city;
  final String address;
  final String paymentMethod;
  final double subtotal;
  final double shippingFee;

  /// خصم كود العرض (إن وُجد).
  final double discountAmount;
  final String discountCode;

  /// خصم عروض الحزم «اشترِ 2» كما يعيده الخادم (0 قبل نشر نقطته).
  final double bundleDiscount;

  final double total;
  final String status;
  final String paymentStatus;
  final List<InvoiceItem> items;

  /// الفاتورة متاحة فقط بعد تأكيد الدفع — لا تُعرض للطلبات غير المدفوعة.
  bool get isPaid => paymentStatus == 'verified' || paymentStatus == 'paid';

  /// خصم إضافي مستنتج من أرقام الخادم نفسه (نقاط الولاء أساساً، إذ لا
  /// يعرض `orderDto` حقلاً مستقلاً لها بعد): الفرق بين (المجموع الفرعي
  /// - خصم الكوبون - خصم الحزم + الشحن) والإجمالي النهائي.
  double get extraDiscount {
    final expected = subtotal - discountAmount - bundleDiscount + shippingFee;
    final value = expected - total;
    return value > 0 ? double.parse(value.toStringAsFixed(2)) : 0;
  }

  factory OrderInvoice.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <InvoiceItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) items.add(InvoiceItem.fromJson(raw));
      }
    }
    return OrderInvoice(
      orderRef: '${json['orderRef'] ?? ''}',
      createdAt: '${json['createdAt'] ?? ''}',
      customerName: '${json['customerName'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      governorate: '${json['governorate'] ?? ''}',
      city: '${json['city'] ?? ''}',
      address: '${json['address'] ?? ''}',
      paymentMethod: '${json['paymentMethod'] ?? ''}',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      discountCode: '${json['discountCode'] ?? ''}',
      bundleDiscount: (json['bundleDiscount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      status: '${json['status'] ?? ''}',
      paymentStatus: '${json['paymentStatus'] ?? ''}',
      items: items,
    );
  }
}

/// توليد فاتورة PDF ومشاركتها — بعد الدفع فقط.
///
/// العربية في حزمة `pdf` وحدها تُرسم حروفاً منفصلة (لا تشكيل عربي
/// فيها)، لذلك تُرسَم الفاتورة أولاً كودجت Flutter (محرك النصوص نفسه
/// في التطبيق — خط Tajawal الرسمي) وتُلتقط صورة، ثم تُضمَّن الصورة في
/// ملف PDF بحجم A4 (مقسّم صفحات عند طول الفاتورة). النتيجة فاتورة
/// عربية سليمة الشكل قابلة للطباعة والمشاركة.
class InvoicePdfService {
  InvoicePdfService._();

  /// هل يمكن تنزيل فاتورة طلب بحالة دفع معينة؟ فقط بعد الدفع.
  static bool canDownloadForPaymentStatus(String paymentStatus) =>
      paymentStatus == 'verified' || paymentStatus == 'paid';

  /// يولّد بايتات PDF للفاتورة. يحتاج سياقاً فيه Overlay (أي صفحة
  /// داخل التطبيق). يرمي عند الفشل فيُظهر المتصل رسالة واضحة.
  static Future<Uint8List> generatePdf(
    OrderInvoice invoice,
    BuildContext context,
  ) async {
    final image = await _rasterize(invoice, context);
    return buildPdfFromImage(image);
  }

  /// يولّد الفاتورة ويشاركها (ملف PDF باسم رقم الطلب).
  static Future<void> sharePdf(
    OrderInvoice invoice,
    BuildContext context,
  ) async {
    final bytes = await generatePdf(invoice, context);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(
            bytes,
            name: 'zakham-invoice-${invoice.orderRef}.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        subject: 'فاتورة ${invoice.orderRef} — دار زخم',
        text: 'فاتورة طلبك ${invoice.orderRef} من دار زخم للعطور.',
      ),
    );
  }

  /// يرسم ودجت الفاتورة خارج الشاشة ويلتقطه صورة (دقة مضاعفة).
  static Future<ui.Image> _rasterize(
    OrderInvoice invoice,
    BuildContext context,
  ) async {
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        top: 0,
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: 794,
            child: RepaintBoundary(
              key: boundaryKey,
              child: InvoiceDocument(invoice: invoice),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    try {
      // إطار كامل حتى تُبنى الطبقة وتُرسَم، ثم مهلة قصيرة للتحويل.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundaryContext = boundaryKey.currentContext;
      if (boundaryContext == null) {
        throw Exception('تعذر تجهيز الفاتورة.');
      }
      final boundary =
          boundaryContext.findRenderObject() as RenderRepaintBoundary;
      return await boundary.toImage(pixelRatio: 2.0);
    } finally {
      entry.remove();
    }
  }

  /// يبني PDF بحجم A4 من صورة الفاتورة، مقسّمة صفحات بنسبة A4 عند
  /// الحاجة. مكشوفة للاختبار (تُستدعى بصورة مصنّعة دون واجهة).
  static Future<Uint8List> buildPdfFromImage(ui.Image image) async {
    final doc = pw.Document(
      title: 'فاتورة دار زخم للعطور',
      author: 'دار زخم للعطور',
    );
    // ارتفاع صفحة A4 بالبكسل نسبةً إلى عرض الصورة (297/210).
    final pageHeightPx = (image.width * 297 / 210).round();
    final pageCount =
        (image.height / pageHeightPx).ceil().clamp(1, 30);
    for (var i = 0; i < pageCount; i++) {
      final top = i * pageHeightPx;
      final sliceHeight = math.min(pageHeightPx, image.height - top);
      if (sliceHeight <= 0) break;
      final slice =
          await _sliceImage(image, 0, top, image.width, sliceHeight);
      final png = await slice.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) continue;
      final memImage = pw.MemoryImage(png.buffer.asUint8List());
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(memImage, fit: pw.BoxFit.fitWidth),
        ),
      );
    }
    return doc.save();
  }

  static Future<ui.Image> _sliceImage(
    ui.Image source,
    int left,
    int top,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }
}
