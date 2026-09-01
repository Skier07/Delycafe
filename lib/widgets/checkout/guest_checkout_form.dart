import 'dart:async';

import 'package:delycafe/constants/app_features.dart';
import 'package:delycafe/constants/bonus_rules.dart';
import 'package:delycafe/models/customer_address.dart';
import 'package:delycafe/models/delivery_config.dart';
import 'package:delycafe/services/delivery_config_service.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/services/checkout_draft_service.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/delivery_address_parser.dart';
import 'package:delycafe/utils/delivery_pricing.dart';
import 'package:delycafe/utils/delivery_schedule.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:delycafe/utils/legal_consent_prompt.dart';
import 'package:delycafe/utils/preorder_availability.dart';
import 'package:delycafe/utils/russian_text_input.dart';
import 'package:delycafe/widgets/checkout/legal_consent_checkout_section.dart';
import 'package:delycafe/widgets/checkout/ordering_closed_banner.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum DeliveryUrgency {
  asap,
  byTime,
}

enum PaymentMethod {
  card,
  sbp,
}

extension DeliveryUrgencyApiValue on DeliveryUrgency {
  String get apiValue {
    switch (this) {
      case DeliveryUrgency.asap:
        return 'asap';
      case DeliveryUrgency.byTime:
        return 'by_time';
    }
  }
}

extension PaymentMethodApiValue on PaymentMethod {
  String get apiValue {
    switch (this) {
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.sbp:
        return 'sbp';
    }
  }
}

class GuestCheckoutData {
  final String name;
  final String phone;
  final String deliveryTypeCode;
  final int deliveryPrice;
  final String address;
  final String addressLocality;
  final String addressEntrance;
  final String addressFloor;
  final String addressApartment;
  final DeliveryUrgency urgency;
  final String? deliveryTime;
  final PaymentMethod paymentMethod;
  final String comment;
  final int bonusSpent;

  const GuestCheckoutData({
    required this.name,
    required this.phone,
    required this.deliveryTypeCode,
    required this.deliveryPrice,
    required this.address,
    required this.addressLocality,
    required this.addressEntrance,
    required this.addressFloor,
    required this.addressApartment,
    required this.urgency,
    required this.deliveryTime,
    required this.paymentMethod,
    required this.comment,
    required this.bonusSpent,
  });
}

class GuestCheckoutForm extends StatefulWidget {
  final int cartTotal;
  final String? initialName;
  final String? initialAddress;
  final String? initialPhone;
  final List<CustomerAddress> savedAddresses;
  final int availableBonuses;
  final bool firstOrderDiscountAvailable;
  final FutureOr<void> Function(GuestCheckoutData data) onSubmit;

  const GuestCheckoutForm({
    super.key,
    required this.cartTotal,
    this.initialName,
    this.initialAddress,
    this.initialPhone,
    this.savedAddresses = const [],
    this.availableBonuses = 0,
    this.firstOrderDiscountAvailable = false,
    required this.onSubmit,
  });

  @override
  State<GuestCheckoutForm> createState() => _GuestCheckoutFormState();
}

class _GuestCheckoutFormState extends State<GuestCheckoutForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _entranceController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _commentController = TextEditingController();
  final _timeController = TextEditingController();

  List<DeliveryZoneConfig> _zones = DeliveryConfig.fallback().zones;
  String _selectedZoneCode = 'ozersk';
  DeliveryUrgency _urgency = DeliveryUrgency.asap;
  PaymentMethod _paymentMethod = PaymentMethod.card;

  CustomerAddress? _selectedSavedAddress;
  bool _useManualAddress = false;

  bool _useBonuses = false;
  bool _isSubmitting = false;
  bool _consentNoticeShown = false;
  bool _draftListenersAttached = false;
  Timer? _scheduleTimer;
  Timer? _draftSaveTimer;

  DeliveryZoneConfig? get _selectedZone {
    for (final zone in _zones) {
      if (zone.code == _selectedZoneCode) {
        return zone;
      }
    }

    return _zones.isNotEmpty ? _zones.first : null;
  }

  int get _scheduleLeadMinutes => _selectedZone?.leadMinutes ?? 90;

  bool get _needsAddress => _selectedZone?.requiresAddress ?? true;

  bool get _isPhoneComplete {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
  }

  DateTime get _now => DeliverySchedule.now;

  bool get _isAcceptingOrders => DeliverySchedule.isAcceptingOrders(_now);

  String? get _preorderBlockMessage {
    final cart = context.read<CartService>();
    return cartPreorderBlockMessage(cart.items);
  }

  bool get _canSubmit {
    final legalConsent = context.read<LegalConsentService>();

    return _isPhoneComplete &&
        !_isSubmitting &&
        _isAcceptingOrders &&
        legalConsent.canPlaceOrder &&
        _preorderBlockMessage == null;
  }

  int get _deliveryPrice {
    final zone = _selectedZone;

    if (zone == null) {
      return 0;
    }

    return calculateDeliveryPrice(zone, widget.cartTotal);
  }

  int get _firstOrderDiscount {
    if (!_hasAutomaticFirstOrderDiscount) return 0;

    return widget.cartTotal * BonusRules.firstOrderDiscountPercent ~/ 100;
  }

  bool get _hasAutomaticFirstOrderDiscount {
    return AppFeatures.firstOrderDiscountEnabled &&
        widget.firstOrderDiscountAvailable;
  }

  int get _pickupDiscount {
    if (_selectedZoneCode != 'pickup') return 0;

    return widget.cartTotal * BonusRules.pickupDiscountPercent ~/ 100;
  }

  int get _productsAfterDiscount {
    final after = widget.cartTotal - _firstOrderDiscount - _pickupDiscount;

    if (after < 0) return 0;

    return after;
  }

  int get _maxBonusSpend {
    if (!AppFeatures.bonusesEnabled || _hasAutomaticFirstOrderDiscount) {
      return 0;
    }

    final maxByPercent =
        _productsAfterDiscount * BonusRules.maxSpendPercent ~/ 100;

    final values = [
      widget.availableBonuses,
      maxByPercent,
      _productsAfterDiscount,
    ];

    return values.reduce((a, b) => a < b ? a : b);
  }

  int get _bonusSpent {
    if (!_useBonuses) return 0;

    return _maxBonusSpend;
  }

  int get _totalWithDelivery {
    final total = _productsAfterDiscount - _bonusSpent + _deliveryPrice;

    if (total < 0) return 0;

    return total;
  }

  String get _deliveryInfo {
    final description = _selectedZone?.checkoutDescription.trim() ?? '';

    if (description.isNotEmpty) {
      return description;
    }

    return _selectedZone?.title ?? '';
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phoneController.text = PhoneInputFormatter.formatDigits(
        widget.initialPhone!,
      );
    }

    if (widget.initialName != null && widget.initialName!.trim().isNotEmpty) {
      _nameController.text = widget.initialName!.trim();
    }

    if (widget.savedAddresses.isNotEmpty) {
      _applySavedAddress(_pickInitialSavedAddress());
    } else if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty) {
      _applyParsedAddress(widget.initialAddress!.trim());
      _useManualAddress = true;
    }

    _scheduleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;

      setState(_syncDeliveryTimeWithSchedule);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(_syncDeliveryTimeWithSchedule);
      _showFirstOrderConsentNoticeIfNeeded();
    });

    unawaited(_restoreDraft());
    unawaited(_loadDeliveryConfig());
  }

  Future<void> _loadDeliveryConfig() async {
    final config = await DeliveryConfigService.instance.fetch();

    if (!mounted) {
      return;
    }

    setState(() {
      _zones = config.zones;

      if (!_zones.any((zone) => zone.code == _selectedZoneCode)) {
        _selectedZoneCode = _zones.first.code;
      }
    });
  }

  Future<void> _restoreDraft() async {
    final draft = await CheckoutDraftService.instance.load();

    if (!mounted) {
      return;
    }

    if (draft != null) {
      setState(() {
        _applyDraft(draft);
      });
    }

    _attachDraftListeners();
  }

  void _applyDraft(CheckoutDraft draft) {
    if (draft.name.trim().isNotEmpty) {
      _nameController.text = draft.name.trim();
    }

    if (draft.phone.trim().isNotEmpty) {
      _phoneController.text = PhoneInputFormatter.formatDigits(draft.phone);
    }

    if (draft.address.trim().isNotEmpty) {
      _addressController.text = draft.address.trim();
    }

    if (draft.entrance.trim().isNotEmpty) {
      _entranceController.text = draft.entrance.trim();
    }

    if (draft.floor.trim().isNotEmpty) {
      _floorController.text = draft.floor.trim();
    }

    if (draft.apartment.trim().isNotEmpty) {
      _apartmentController.text = draft.apartment.trim();
    }

    if (draft.comment.trim().isNotEmpty) {
      _commentController.text = draft.comment.trim();
    }

    if (draft.deliveryTime.trim().isNotEmpty) {
      _timeController.text = draft.deliveryTime.trim();
    }

    _selectedZoneCode = _deliveryCodeFromApi(draft.deliveryType);
    _urgency = _urgencyFromApi(draft.urgency);
    _paymentMethod = _paymentMethodFromApi(draft.paymentMethod);
    _useManualAddress = draft.useManualAddress;

    if (_useManualAddress) {
      _selectedSavedAddress = null;
    }
  }

  String _deliveryCodeFromApi(String value) {
    if (_zones.any((zone) => zone.code == value)) {
      return value;
    }

    return _zones.first.code;
  }

  DeliveryUrgency _urgencyFromApi(String value) {
    return value == 'by_time' ? DeliveryUrgency.byTime : DeliveryUrgency.asap;
  }

  PaymentMethod _paymentMethodFromApi(String value) {
    return value == 'sbp' ? PaymentMethod.sbp : PaymentMethod.card;
  }

  void _attachDraftListeners() {
    if (_draftListenersAttached) {
      return;
    }

    _draftListenersAttached = true;

    for (final controller in [
      _nameController,
      _phoneController,
      _addressController,
      _entranceController,
      _floorController,
      _apartmentController,
      _commentController,
      _timeController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveDraft());
    });
  }

  CheckoutDraft _buildDraft() {
    return CheckoutDraft(
      name: _nameController.text.trim(),
      phone: _phoneController.text,
      address: _addressController.text.trim(),
      entrance: _entranceController.text.trim(),
      floor: _floorController.text.trim(),
      apartment: _apartmentController.text.trim(),
      comment: _commentController.text.trim(),
      deliveryTime: _timeController.text.trim(),
      deliveryType: _selectedZoneCode,
      urgency: _urgency.apiValue,
      paymentMethod: _paymentMethod.apiValue,
      useManualAddress: _useManualAddress,
    );
  }

  Future<void> _saveDraft() async {
    await CheckoutDraftService.instance.save(_buildDraft());
  }

  void _showFirstOrderConsentNoticeIfNeeded() {
    if (!mounted || _consentNoticeShown) {
      return;
    }

    final consent = context.read<LegalConsentService>();

    if (consent.canPlaceOrder) {
      return;
    }

    _consentNoticeShown = true;
    unawaited(showLegalConsentRequiredDialog(context));
  }

  void _syncDeliveryTimeWithSchedule() {
    final previewTime = DeliverySchedule.previewTimeLabel(
      _now,
      _selectedZoneCode,
      leadMinutes: _scheduleLeadMinutes,
    );

    if (!_isAcceptingOrders) {
      _timeController.text = previewTime;
      return;
    }

    if (_urgency != DeliveryUrgency.byTime) {
      _timeController.clear();
      return;
    }

    final slots = DeliverySchedule.availableSlots(
      _now,
      _selectedZoneCode,
      leadMinutes: _scheduleLeadMinutes,
    );

    if (slots.isEmpty) {
      _timeController.text = previewTime;
      return;
    }

    final selected = _timeController.text.trim();

    if (selected.isEmpty) {
      _timeController.text = DeliverySchedule.formatTime(slots.first);
      return;
    }

    final stillValid = slots.any(
      (slot) => DeliverySchedule.formatTime(slot) == selected,
    );

    if (!stillValid) {
      _timeController.text = DeliverySchedule.formatTime(slots.first);
    }
  }

  CustomerAddress? _pickInitialSavedAddress() {
    for (final address in widget.savedAddresses) {
      if (address.isDefault) {
        return address;
      }
    }

    return widget.savedAddresses.first;
  }

  void _applySavedAddress(CustomerAddress? address) {
    if (address == null) {
      return;
    }

    final fields = address.checkoutFields;

    _selectedSavedAddress = address;
    _useManualAddress = false;
    _addressController.text = fields.street;
    _entranceController.text = fields.entrance;
    _floorController.text = fields.floor;
    _apartmentController.text = fields.apartment;

    if (address.comment.trim().isNotEmpty) {
      _commentController.text = address.comment.trim();
    }
  }

  void _applyParsedAddress(String rawAddress) {
    final fields = parseDeliveryAddress(rawAddress);

    _selectedSavedAddress = null;
    _addressController.text = fields.street;
    _entranceController.text = fields.entrance;
    _floorController.text = fields.floor;
    _apartmentController.text = fields.apartment;
  }

  void _selectManualAddress() {
    setState(() {
      _useManualAddress = true;
      _selectedSavedAddress = null;
    });
    _scheduleDraftSave();
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _draftSaveTimer?.cancel();
    final draft = _buildDraft();
    unawaited(CheckoutDraftService.instance.save(draft));
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _entranceController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    _commentController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  String _paymentTitle(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.card:
        return 'Картой';
      case PaymentMethod.sbp:
        return 'СБП';
    }
  }

  Future<void> _pickTime() async {
    final slots = DeliverySchedule.availableSlots(
      _now,
      _selectedZoneCode,
      leadMinutes: _scheduleLeadMinutes,
    );

    if (slots.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DeliverySchedule.isKitchenClosed(_now)
                ? DeliverySchedule.closedSubmitButtonLabel(_now)
                : DeliverySchedule.closedMessage(_now),
          ),
        ),
      );
      return;
    }

    final slotLabels =
        slots.map(DeliverySchedule.formatTime).toList(growable: false);

    var selectedIndex = 0;
    final current = _timeController.text.trim();

    if (current.isNotEmpty) {
      final index = slotLabels.indexOf(current);

      if (index >= 0) {
        selectedIndex = index;
      }
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Material(
          color: Colors.white,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
            child: SizedBox(
              height: 320,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Отмена',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Text(
                            'Выберите время',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _timeController.text =
                                    slotLabels[selectedIndex];
                              });
                              _scheduleDraftSave();

                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Готово',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedIndex,
                        ),
                        itemExtent: 42,
                        onSelectedItemChanged: (index) {
                          selectedIndex = index;
                        },
                        children: slotLabels
                            .map(
                              (label) => Center(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;

    if (!_isAcceptingOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DeliverySchedule.closedMessage(_now)),
        ),
      );
      return;
    }

    final preorderBlock = _preorderBlockMessage;

    if (preorderBlock != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(preorderBlock)),
      );
      return;
    }

    final legalConsent = context.read<LegalConsentService>();

    if (!legalConsent.canPlaceOrder) {
      await showLegalConsentRequiredDialog(context);
      return;
    }

    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    if (phoneDigits.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите номер телефона полностью'),
        ),
      );
      return;
    }

    final fullPhone = '+7$phoneDigits';

    if (context.read<AuthService>().isLoggedIn) {
      try {
        await legalConsent.ensureSyncedForOrder();
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось сохранить согласия: $error'),
          ),
        );
        return;
      }
    }

    final data = GuestCheckoutData(
      name: _nameController.text.trim(),
      phone: fullPhone,
      deliveryTypeCode: _selectedZoneCode,
      deliveryPrice: _deliveryPrice,
      address: _needsAddress ? _addressController.text.trim() : 'Самовывоз',
      addressLocality:
          _needsAddress ? (_selectedZone?.defaultLocality ?? '') : '',
      addressEntrance: _needsAddress ? _entranceController.text.trim() : '',
      addressFloor: _needsAddress ? _floorController.text.trim() : '',
      addressApartment: _needsAddress ? _apartmentController.text.trim() : '',
      urgency: _urgency,
      deliveryTime: _urgency == DeliveryUrgency.byTime
          ? _timeController.text.trim()
          : null,
      paymentMethod: _paymentMethod,
      comment: _commentController.text.trim(),
      bonusSpent: _bonusSpent,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(data);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось оформить заказ: $error'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final legalConsent = context.watch<LegalConsentService>();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isAcceptingOrders) ...[
            OrderingClosedBanner(now: _now),
            const SizedBox(height: 20),
          ],
          if (_preorderBlockMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                _preorderBlockMessage!,
                style: const TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const _BlockTitle('Контактные данные'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            keyboardType: RussianTextInput.text,
            hintLocales: RussianTextInput.hintLocales,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('Имя'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите имя';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              PhoneInputFormatter(),
            ],
            decoration: _inputDecoration(
              'Телефон',
              prefixText: '+7 ',
            ),
            onChanged: (_) {
              setState(() {});
            },
            validator: (value) {
              final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';

              if (digits.isEmpty) {
                return 'Введите телефон';
              }

              if (digits.length != 10) {
                return 'Введите номер полностью';
              }

              return null;
            },
          ),
          const SizedBox(height: 24),
          const _BlockTitle('Способ получения'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final childAspectRatio = constraints.maxWidth <= 340
                  ? 2.0
                  : constraints.maxWidth <= 390
                      ? 2.25
                      : 2.7;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: childAspectRatio,
                children: _zones.map((zone) {
                  return _ChoiceCard(
                    title: zone.title,
                    selected: _selectedZoneCode == zone.code,
                    onTap: () {
                      setState(() {
                        _selectedZoneCode = zone.code;
                        _syncDeliveryTimeWithSchedule();
                      });
                      _scheduleDraftSave();
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.header.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _deliveryInfo,
              style: TextStyle(
                height: 1.45,
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.78),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_needsAddress) ...[
            if (widget.savedAddresses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Куда доставить?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 10),
              ...widget.savedAddresses.map((address) {
                final selected = !_useManualAddress &&
                    _selectedSavedAddress?.id == address.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SavedAddressCard(
                    title: address.title.trim().isNotEmpty
                        ? address.title.trim()
                        : 'Адрес',
                    subtitle: address.checkoutDisplayLine,
                    selected: selected,
                    isDefault: address.isDefault,
                    onTap: () {
                      setState(() {
                        _applySavedAddress(address);
                      });
                      _scheduleDraftSave();
                    },
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _SavedAddressCard(
                  title: 'Другой адрес',
                  subtitle: 'Указать адрес вручную',
                  selected: _useManualAddress,
                  onTap: _selectManualAddress,
                ),
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              keyboardType: RussianTextInput.text,
              hintLocales: RussianTextInput.hintLocales,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Улица, дом'),
              validator: (value) {
                if (!_needsAddress) return null;

                if (value == null || value.trim().isEmpty) {
                  return 'Введите адрес доставки';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _entranceController,
                    textInputAction: TextInputAction.next,
                    keyboardType: RussianTextInput.digitsKeyboardType,
                    inputFormatters: RussianTextInput.digitsOnlyFormatters,
                    decoration: _inputDecoration('Подъезд'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _floorController,
                    textInputAction: TextInputAction.next,
                    keyboardType: RussianTextInput.digitsKeyboardType,
                    inputFormatters: RussianTextInput.digitsOnlyFormatters,
                    decoration: _inputDecoration('Этаж'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _apartmentController,
                    textInputAction: TextInputAction.next,
                    keyboardType: RussianTextInput.digitsKeyboardType,
                    inputFormatters: RussianTextInput.digitsOnlyFormatters,
                    decoration: _inputDecoration('Квартира'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const _BlockTitle('Когда доставить'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  title: 'Как можно скорее',
                  subtitle: DeliverySchedule.asapChoiceLabel(
                    _now,
                    _selectedZoneCode,
                    leadMinutes: _scheduleLeadMinutes,
                  ),
                  selected: _urgency == DeliveryUrgency.asap,
                  onTap: () {
                    setState(() {
                      _urgency = DeliveryUrgency.asap;
                      _syncDeliveryTimeWithSchedule();
                    });
                    _scheduleDraftSave();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceCard(
                  title: 'Ко времени',
                  subtitle: _isAcceptingOrders
                      ? (_timeController.text.trim().isNotEmpty
                          ? _timeController.text.trim()
                          : 'выберите')
                      : DeliverySchedule.previewTimeLabel(
                          _now,
                          _selectedZoneCode,
                          leadMinutes: _scheduleLeadMinutes,
                        ),
                  selected: _urgency == DeliveryUrgency.byTime,
                  onTap: () {
                    setState(() {
                      _urgency = DeliveryUrgency.byTime;
                      _syncDeliveryTimeWithSchedule();
                    });
                    _scheduleDraftSave();
                  },
                ),
              ),
            ],
          ),
          if (_urgency == DeliveryUrgency.asap) ...[
            const SizedBox(height: 12),
            Text(
              DeliverySchedule.asapEstimateMessage(
                _now,
                _selectedZoneCode,
                leadMinutes: _scheduleLeadMinutes,
              ),
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withValues(
                  alpha: _isAcceptingOrders ? 0.62 : 0.45,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_urgency == DeliveryUrgency.byTime) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeController,
              readOnly: true,
              onTap: _isAcceptingOrders ? _pickTime : null,
              decoration: _inputDecoration('Выберите время'),
              validator: (value) {
                if (!_isAcceptingOrders) {
                  return null;
                }

                if (_urgency == DeliveryUrgency.byTime &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Выберите время';
                }

                if (_urgency == DeliveryUrgency.byTime) {
                  final slots = DeliverySchedule.availableSlots(
                    _now,
                    _selectedZoneCode,
                    leadMinutes: _scheduleLeadMinutes,
                  ).map(DeliverySchedule.formatTime);

                  if (!slots.contains(value?.trim())) {
                    return 'Выбранное время недоступно';
                  }
                }

                return null;
              },
            ),
          ],
          const SizedBox(height: 24),
          const _BlockTitle('Оплата'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  title: _paymentTitle(PaymentMethod.card),
                  selected: _paymentMethod == PaymentMethod.card,
                  onTap: () {
                    setState(() {
                      _paymentMethod = PaymentMethod.card;
                    });
                    _scheduleDraftSave();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceCard(
                  title: _paymentTitle(PaymentMethod.sbp),
                  selected: _paymentMethod == PaymentMethod.sbp,
                  onTap: () {
                    setState(() {
                      _paymentMethod = PaymentMethod.sbp;
                    });
                    _scheduleDraftSave();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (AppFeatures.bonusesEnabled ||
              AppFeatures.firstOrderDiscountEnabled) ...[
            const _BlockTitle('Скидки и бонусы'),
            const SizedBox(height: 12),
            if (_hasAutomaticFirstOrderDiscount)
              _DiscountInfoCard(
                discountAmount: _firstOrderDiscount,
              )
            else if (AppFeatures.bonusesEnabled)
              _BonusSpendCard(
                availableBonuses: widget.availableBonuses,
                bonusSpent: _bonusSpent,
                useBonuses: _useBonuses,
                onChanged: widget.availableBonuses > 0 && _maxBonusSpend > 0
                    ? (value) {
                        setState(() {
                          _useBonuses = value;
                        });
                      }
                    : null,
              ),
            const SizedBox(height: 24),
          ],
          const _BlockTitle('Комментарий'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _commentController,
            keyboardType: RussianTextInput.multiline,
            hintLocales: RussianTextInput.hintLocales,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: _inputDecoration('Комментарий к заказу'),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _PriceRow(
                  title: 'Товары',
                  value: '${widget.cartTotal} ₽',
                ),
                const SizedBox(height: 10),
                if (AppFeatures.firstOrderDiscountEnabled &&
                    _firstOrderDiscount > 0) ...[
                  _PriceRow(
                    title: 'Скидка первого заказа',
                    value: '-$_firstOrderDiscount ₽',
                  ),
                  const SizedBox(height: 10),
                ],
                if (_pickupDiscount > 0) ...[
                  _PriceRow(
                    title:
                        'Скидка самовывоза ${BonusRules.pickupDiscountPercent}%',
                    value: '-$_pickupDiscount ₽',
                  ),
                  const SizedBox(height: 10),
                ],
                if (AppFeatures.bonusesEnabled && _bonusSpent > 0) ...[
                  _PriceRow(
                    title: 'Списано бонусов',
                    value: '-$_bonusSpent ₽',
                  ),
                  const SizedBox(height: 10),
                ],
                _PriceRow(
                  title: 'Доставка',
                  value:
                      _deliveryPrice == 0 ? 'Бесплатно' : '$_deliveryPrice ₽',
                ),
                const Divider(height: 24),
                _PriceRow(
                  title: 'Итого',
                  value: '$_totalWithDelivery ₽',
                  isTotal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const LegalConsentCheckoutSection(),
          const SizedBox(height: 24),
          SafeArea(
            top: false,
            child: AuthButton(
              text: _isSubmitting
                  ? 'Оформляем...'
                  : !_isAcceptingOrders
                      ? DeliverySchedule.closedSubmitButtonLabel(_now)
                      : _preorderBlockMessage != null
                          ? 'Уберите недоступные позиции'
                          : !legalConsent.canPlaceOrder
                              ? 'Примите условия'
                              : 'Оформить заказ',
              onPressed: _isSubmitting || !_isAcceptingOrders
                  ? null
                  : _preorderBlockMessage != null
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_preorderBlockMessage!)),
                          );
                        }
                      : !legalConsent.canPlaceOrder
                          ? () => showLegalConsentRequiredDialog(context)
                          : _canSubmit
                              ? _submit
                              : null,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: Colors.black45,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.header,
          width: 1.4,
        ),
      ),
    );
  }
}

class _DiscountInfoCard extends StatelessWidget {
  final int discountAmount;

  const _DiscountInfoCard({
    required this.discountAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.header.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.header.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.local_offer_rounded,
            color: AppColors.header,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Скидка 20% на первый заказ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Применится автоматически. Скидка: $discountAmount ₽',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Бонусы за этот заказ начислятся после оформления.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.black.withValues(alpha: 0.50),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BonusSpendCard extends StatelessWidget {
  final int availableBonuses;
  final int bonusSpent;
  final bool useBonuses;
  final ValueChanged<bool>? onChanged;

  const _BonusSpendCard({
    required this.availableBonuses,
    required this.bonusSpent,
    required this.useBonuses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasBonuses = availableBonuses > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.stars_rounded,
            color: AppColors.header,
            size: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Списать бонусы',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasBonuses
                      ? useBonuses
                          ? 'Спишется до ${BonusRules.maxSpendPercent}%: $bonusSpent бонусов'
                          : 'Доступно: $availableBonuses · до ${BonusRules.maxSpendPercent}% суммы'
                      : 'Бонусов пока нет',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: useBonuses,
            activeThumbColor: AppColors.header,
            activeTrackColor: AppColors.header.withValues(alpha: 0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;

  const _SavedAddressCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.isDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.header.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.header
                  : Colors.black.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.header : Colors.black45,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.header.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'По умолчанию',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.header,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.black.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 145;
        final titleFontSize = compact
            ? 14.0
            : constraints.maxWidth <= 175
                ? 15.0
                : 16.0;
        final subtitleFontSize = compact ? 11.5 : 13.0;
        final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
        final titleText = Text(
          title,
          textAlign: TextAlign.center,
          maxLines: hasSubtitle ? 2 : 1,
          softWrap: hasSubtitle,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w700,
          ),
        );

        final content = hasSubtitle
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      titleText,
                      SizedBox(height: compact ? 2 : 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.55),
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: titleText,
              );

        return GestureDetector(
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: compact ? 9 : 12,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.header : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.header
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: content,
          ),
        );
      },
    );
  }
}

class _BlockTitle extends StatelessWidget {
  final String text;

  const _BlockTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isTotal;

  const _PriceRow({
    required this.title,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTotal ? 18 : 15,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: Colors.black.withValues(alpha: isTotal ? 1 : 0.65),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 15,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal ? AppColors.header : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  static String formatDigits(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }

    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    return _format(digits);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var cursorPosition = newValue.selection.start;

    if (cursorPosition < 0) {
      cursorPosition = newValue.text.length;
    }

    var digitsBeforeCursor = _countDigits(
      newValue.text.substring(0, cursorPosition),
    );

    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }

    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    if (digitsBeforeCursor > digits.length) {
      digitsBeforeCursor = digits.length;
    }

    final formatted = _format(digits);

    final newCursorPosition = _calculateCursorPosition(
      formatted,
      digitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  static int _countDigits(String text) {
    return text.replaceAll(RegExp(r'\D'), '').length;
  }

  static String _format(String digits) {
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) {
        buffer.write(' ');
      }

      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  int _calculateCursorPosition(String formatted, int digitIndex) {
    var digitCount = 0;

    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitCount++;
      }

      if (digitCount == digitIndex) {
        return i + 1;
      }
    }

    return formatted.length;
  }
}
