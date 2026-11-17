import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/models/cart_item.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/services/favorites_offer_service.dart';
import 'package:house_of_zakham/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product(
  String id,
  String name, {
  double price = 500,
  bool inStock = true,
}) =>
    Product(
      id: id,
      name: name,
      price: price,
      currency: 'EGP',
      size: '100 ml',
      category: 'official',
      topNotes: const <String>['برغموت'],
      heartNotes: const <String>['ورد'],
      baseNotes: const <String>['عود'],
      image: 'https://zakhamhouse.shop/assets/products/$id.webp',
      inStock: inStock,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderTap payloads', () {
    test('parses cart, collection, reorder, offer and unknown', () {
      expect(ReminderTap.parse('zakham:cart').kind, ReminderTapKind.cart);
      expect(
        ReminderTap.parse('zakham:collection').kind,
        ReminderTapKind.collection,
      );
      final reorder = ReminderTap.parse('zakham:reorder:layl');
      expect(reorder.kind, ReminderTapKind.reorder);
      expect(reorder.productId, 'layl');
      final offer = ReminderTap.parse('zakham:offer:royal');
      expect(offer.kind, ReminderTapKind.offer);
      expect(offer.productId, 'royal');
      expect(ReminderTap.parse('zakham:reorder:').kind, ReminderTapKind.unknown);
      expect(ReminderTap.parse(null).kind, ReminderTapKind.unknown);
      expect(ReminderTap.parse('random').kind, ReminderTapKind.unknown);
    });

    test('payload builders round-trip through parse', () {
      expect(
        ReminderTap.parse(ReminderTap.reorderPayload('sultan')).productId,
        'sultan',
      );
      expect(
        ReminderTap.parse(ReminderTap.offerPayload('musk')).productId,
        'musk',
      );
      expect(
        ReminderTap.parse(ReminderTap.cartPayload).kind,
        ReminderTapKind.cart,
      );
      expect(
        ReminderTap.parse(ReminderTap.collectionPayload).kind,
        ReminderTapKind.collection,
      );
    });
  });

  group('Reminder timing decisions', () {
    test('cart reminder fires 4 hours after the cart change', () {
      final now = DateTime(2026, 11, 18, 10, 0);
      expect(
        cartReminderFireAt(now),
        DateTime(2026, 11, 18, 14, 0),
      );
      expect(ReminderService.cartReminderDelay, const Duration(hours: 4));
    });

    test('reorder reminder fires 60 days after the order', () {
      final now = DateTime(2026, 11, 18, 10, 0);
      expect(reorderFireAt(now), DateTime(2027, 1, 17, 10, 0));
      expect(
        ReminderService.reorderReminderDelay,
        const Duration(days: 60),
      );
    });

    test('empty-cart fires 3 days after last activity', () {
      final now = DateTime(2026, 11, 18, 10, 0);
      final lastActivity = DateTime(2026, 11, 17, 10, 0);
      expect(
        emptyCartFireAt(lastActivity, now),
        DateTime(2026, 11, 20, 10, 0),
      );
      expect(ReminderService.emptyCartDelay, const Duration(days: 3));
    });

    test('empty-cart falls back to tomorrow when the moment passed', () {
      final now = DateTime(2026, 11, 18, 10, 0);
      final lastActivity = DateTime(2026, 11, 10, 10, 0);
      expect(
        emptyCartFireAt(lastActivity, now),
        DateTime(2026, 11, 19, 10, 0),
      );
    });

    test('empty-cart cap allows at most once every 3 days', () {
      final now = DateTime(2026, 11, 18, 10, 0);
      expect(emptyCartCapAllows(null, now), isTrue);
      expect(
        emptyCartCapAllows(DateTime(2026, 11, 16, 10, 0), now),
        isFalse,
      );
      expect(
        emptyCartCapAllows(DateTime(2026, 11, 15, 10, 0), now),
        isTrue,
      );
      expect(
        emptyCartCapAllows(DateTime(2026, 11, 14, 10, 0), now),
        isTrue,
      );
      expect(
        ReminderService.emptyCartMinInterval,
        const Duration(days: 3),
      );
    });
  });

  group('Favorite changes detection', () {
    test('detects a price drop on a favorite only', () {
      final fresh = <Product>[
        _product('layl', 'ليل زخم', price: 400),
        _product('royal', 'عطر زخم رويال', price: 500),
      ];
      final previous = <Product>[
        _product('layl', 'ليل زخم', price: 500),
        _product('royal', 'عطر زخم رويال', price: 500),
      ];
      final changes = detectFavoriteChanges(
        fresh: fresh,
        previous: previous,
        favoriteIds: {'layl', 'royal'},
      );
      expect(changes.length, 1);
      expect(changes.first.kind, FavoriteChangeKind.priceDrop);
      expect(changes.first.product.id, 'layl');
      expect(changes.first.oldPrice, 500);
      expect(changes.first.newPrice, 400);
      expect(changes.first.message, contains('انخفض سعر'));
    });

    test('detects back-in-stock and ignores price increases', () {
      final fresh = <Product>[
        _product('musk', 'عطر خطوط المسك والتنوع', price: 500),
        _product('sultan', 'سلطان', price: 600),
      ];
      final previous = <Product>[
        _product('musk', 'عطر خطوط المسك والتنوع', inStock: false),
        _product('sultan', 'سلطان', price: 500),
      ];
      final changes = detectFavoriteChanges(
        fresh: fresh,
        previous: previous,
        favoriteIds: {'musk', 'sultan'},
      );
      expect(changes.length, 1);
      expect(changes.first.kind, FavoriteChangeKind.backInStock);
      expect(changes.first.product.id, 'musk');
      expect(changes.first.message, contains('عاد'));
    });

    test('ignores changes on non-favorites and empty input', () {
      final fresh = <Product>[_product('layl', 'ليل زخم', price: 100)];
      final previous = <Product>[_product('layl', 'ليل زخم', price: 500)];
      expect(
        detectFavoriteChanges(
          fresh: fresh,
          previous: previous,
          favoriteIds: {'royal'},
        ),
        isEmpty,
      );
      expect(
        detectFavoriteChanges(
          fresh: fresh,
          previous: previous,
          favoriteIds: {'layl'},
        ),
        hasLength(1),
      );
      expect(
        detectFavoriteChanges(
          fresh: const <Product>[],
          previous: previous,
          favoriteIds: {'layl'},
        ),
        isEmpty,
      );
    });
  });

  group('ReminderService persistence (plugin calls fail silently here)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('reminders are enabled by default and the toggle persists', () async {
      final service = ReminderService.instance;
      expect(await service.isEnabled(), isTrue);
      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);
      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
    });

    test('order completion persists reorder entries for 60 days', () async {
      final service = ReminderService.instance;
      final now = DateTime(2026, 11, 18, 10, 0);
      await service.onOrderCompleted(
        orderRef: 'ZH-NOV-000099',
        items: <CartItem>[
          CartItem(product: _product('layl', 'ليل زخم')),
          CartItem(product: _product('royal', 'عطر زخم رويال')),
          CartItem(product: _product('layl', 'ليل زخم')),
        ],
        now: now,
      );
      final pending = await service.pendingReorders();
      // Duplicate product in the order is stored once.
      expect(pending.map((e) => e.productId), <String>['layl', 'royal']);
      expect(pending.first.orderRef, 'ZH-NOV-000099');
      expect(pending.first.fireAt, DateTime(2027, 1, 17, 10, 0));
      expect(pending.first.notificationId, 1100);
      expect(pending.last.notificationId, 1101);
    });

    test('adding a product to the cart cancels its reorder entry', () async {
      final service = ReminderService.instance;
      final now = DateTime(2026, 11, 18, 10, 0);
      await service.onOrderCompleted(
        orderRef: 'ZH-NOV-000100',
        items: <CartItem>[
          CartItem(product: _product('layl', 'ليل زخم')),
          CartItem(product: _product('royal', 'عطر زخم رويال')),
        ],
        now: now,
      );
      expect(await service.pendingReorders(), hasLength(2));
      await service.onCartChanged(
        cartEmpty: false,
        cartProductIds: {'layl'},
        now: now.add(const Duration(hours: 1)),
      );
      final pending = await service.pendingReorders();
      expect(pending.map((e) => e.productId), <String>['royal']);
    });

    test('non-empty cart persists a 4-hour reminder fire time', () async {
      final service = ReminderService.instance;
      final now = DateTime(2026, 11, 18, 10, 0);
      await service.onCartChanged(
        cartEmpty: false,
        cartProductIds: {'layl'},
        now: now,
      );
      expect(
        await service.cartReminderFireTime(),
        DateTime(2026, 11, 18, 14, 0),
      );
    });

    test('empty cart arms the empty-cart reminder 3 days out', () async {
      final service = ReminderService.instance;
      final now = DateTime(2026, 11, 18, 10, 0);
      await service.onCartChanged(
        cartEmpty: true,
        cartProductIds: const <String>{},
        now: now,
      );
      expect(
        await service.emptyCartLastSentAt(),
        DateTime(2026, 11, 21, 10, 0),
      );
    });

    test('empty-cart is not re-armed within the 3-day cap', () async {
      final service = ReminderService.instance;
      final now = DateTime(2026, 11, 18, 10, 0);
      await service.onCartChanged(
        cartEmpty: true,
        cartProductIds: const <String>{},
        now: now,
      );
      final first = await service.emptyCartLastSentAt();
      await service.onCartChanged(
        cartEmpty: true,
        cartProductIds: const <String>{},
        now: now.add(const Duration(days: 1)),
      );
      expect(await service.emptyCartLastSentAt(), first);
    });
  });

  group('FavoritesOfferService toggle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('favorites-offer alerts are enabled by default', () async {
      final service = FavoritesOfferService();
      expect(await service.isEnabled(), isTrue);
      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);
    });

    test('sync without an FCM token returns false quietly', () async {
      final service = FavoritesOfferService();
      expect(await service.syncFavorites(), isFalse);
    });
  });
}
