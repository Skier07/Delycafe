import 'dart:async';

import 'package:delycafe/constants/bonus_rules.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DeliveryType {
  ozersk,
  prom,
  tatysh,
  pickup,
}

enum DeliveryUrgency {
  asap,
  byTime,
}

enum PaymentMethod {
  card,
  sbp,
}

extension DeliveryTypeApiValue on DeliveryType {
  String get apiValue {
    switch (this) {
      case DeliveryType.ozersk:
        return 'ozersk';
      case DeliveryType.prom:
        return 'promploshadka';
      case DeliveryType.tatysh:
        return 'tatysh';
      case DeliveryType.pickup:
        return 'pickup';
    }
  }

  String get defaultLocality {
    switch (this) {
      case DeliveryType.ozersk:
        return 'Озерск';
      case DeliveryType.prom:
        return 'Промплощадка';
      case DeliveryType.tatysh:
        return 'Татыш';
      case DeliveryType.pickup:
        return '';
    }
  }
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
  final DeliveryType deliveryType;
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
    required this.deliveryType,
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
  final int availableBonuses;
  final bool firstOrderDiscountAvailable;
  final FutureOr<void> Function(GuestCheckoutData data) onSubmit;

  const GuestCheckoutForm({
    super.key,
    required this.cartTotal,
    this.initialName,
    this.initialAddress,
    this.initialPhone,
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

  DeliveryType _deliveryType = DeliveryType.ozersk;
  DeliveryUrgency _urgency = DeliveryUrgency.asap;
  PaymentMethod _paymentMethod = PaymentMethod.card;

  bool _useBonuses = false;
  bool _isSubmitting = false;

  static const int _promDeliveryPrice = 350;
  static const int _tatyshDeliveryPrice = 450;

  bool get _isPhoneComplete {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
  }

  bool get _canSubmit {
    return _isPhoneComplete && !_isSubmitting;
  }

  bool get _needsAddress {
    return _deliveryType != DeliveryType.pickup;
  }

  bool get _hasAutomaticFirstOrderDiscount {
    return widget.firstOrderDiscountAvailable;
  }

  int get _deliveryPrice {
    switch (_deliveryType) {
      case DeliveryType.ozersk:
        if (widget.cartTotal >= 1700) return 0;
        if (widget.cartTotal >= 1000) return 200;
        return 250;

      case DeliveryType.prom:
        return _promDeliveryPrice;

      case DeliveryType.tatysh:
        return _tatyshDeliveryPrice;

      case DeliveryType.pickup:
        return 0;
    }
  }

  int get _firstOrderDiscount {
    if (!_hasAutomaticFirstOrderDiscount) return 0;

    return widget.cartTotal * BonusRules.firstOrderDiscountPercent ~/ 100;
  }

  int get _maxBonusSpend {
    if (_hasAutomaticFirstOrderDiscount) return 0;

    final maxByPercent = widget.cartTotal * BonusRules.maxSpendPercent ~/ 100;

    final values = [
      widget.availableBonuses,
      maxByPercent,
      widget.cartTotal,
    ];

    return values.reduce((a, b) => a < b ? a : b);
  }

  int get _bonusSpent {
    if (!_useBonuses) return 0;

    return _maxBonusSpend;
  }

  int get _totalWithDelivery {
    final total =
        widget.cartTotal - _firstOrderDiscount - _bonusSpent + _deliveryPrice;

    if (total < 0) return 0;

    return total;
  }

  String get _deliveryInfo {
    switch (_deliveryType) {
      case DeliveryType.ozersk:
        return 'Озёрск: от 1700 ₽ бесплатно, от 1000 до 1700 ₽ - 200 ₽, до 1000 ₽ - 250';

      case DeliveryType.prom:
        return 'Промплощадка: доставка $_promDeliveryPrice ₽';

      case DeliveryType.tatysh:
        return 'Татыш: доставка $_tatyshDeliveryPrice ₽, минимальное время - около 2 часов';

      case DeliveryType.pickup:
        return 'Самовывоз: заберите заказ самостоятельно из кафе';
    }
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

    if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty) {
      _addressController.text = widget.initialAddress!.trim();
    }
  }

  @override
  void dispose() {
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

  String _deliveryTitle(DeliveryType type) {
    switch (type) {
      case DeliveryType.ozersk:
        return 'Озёрск';
      case DeliveryType.prom:
        return 'Промплощадка';
      case DeliveryType.tatysh:
        return 'Татыш';
      case DeliveryType.pickup:
        return 'Самовывоз';
    }
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
    const minuteInterval = 5;

    final now = DateTime.now();

    final roundedMinute = (now.minute / minuteInterval).ceil() * minuteInterval;

    var selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      roundedMinute,
    );

    await showCupertinoModalPopup(
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
                              final hour = selectedDateTime.hour
                                  .toString()
                                  .padLeft(2, '0');
                              final minute = selectedDateTime.minute
                                  .toString()
                                  .padLeft(2, '0');

                              setState(() {
                                _timeController.text = '$hour:$minute';
                              });

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
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: true,
                        minuteInterval: minuteInterval,
                        initialDateTime: selectedDateTime,
                        onDateTimeChanged: (DateTime value) {
                          selectedDateTime = value;
                        },
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

    final data = GuestCheckoutData(
      name: _nameController.text.trim(),
      phone: fullPhone,
      deliveryType: _deliveryType,
      deliveryPrice: _deliveryPrice,
      address: _needsAddress ? _addressController.text.trim() : 'Самовывоз',
      addressLocality: _needsAddress ? _deliveryType.defaultLocality : '',
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle('Контактные данные'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
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
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.7,
            children: DeliveryType.values.map((type) {
              return _ChoiceCard(
                title: _deliveryTitle(type),
                selected: _deliveryType == type,
                onTap: () {
                  setState(() {
                    _deliveryType = type;
                  });
                },
              );
            }).toList(),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration('Подъезд'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _floorController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration('Этаж'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _apartmentController,
                    textInputAction: TextInputAction.next,
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
                  selected: _urgency == DeliveryUrgency.asap,
                  onTap: () {
                    setState(() {
                      _urgency = DeliveryUrgency.asap;
                      _timeController.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceCard(
                  title: 'Ко времени',
                  selected: _urgency == DeliveryUrgency.byTime,
                  onTap: () {
                    setState(() {
                      _urgency = DeliveryUrgency.byTime;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_urgency == DeliveryUrgency.byTime) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeController,
              readOnly: true,
              onTap: _pickTime,
              decoration: _inputDecoration('Выберите время'),
              validator: (value) {
                if (_urgency == DeliveryUrgency.byTime &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Выберите время';
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
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _BlockTitle('Скидки и бонусы'),
          const SizedBox(height: 12),
          if (_hasAutomaticFirstOrderDiscount)
            _DiscountInfoCard(
              discountAmount: _firstOrderDiscount,
            )
          else
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
          const _BlockTitle('Комментарий'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _commentController,
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
                if (_firstOrderDiscount > 0) ...[
                  _PriceRow(
                    title: 'Скидка первого заказа',
                    value: '-$_firstOrderDiscount ₽',
                  ),
                  const SizedBox(height: 10),
                ],
                if (_bonusSpent > 0) ...[
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
          SafeArea(
            top: false,
            child: AuthButton(
              text: _isSubmitting ? 'Оформляем...' : 'Оформить заказ',
              onPressed: _canSubmit ? _submit : null,
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
                          ? 'Будет списано: $bonusSpent бонусов'
                          : 'Доступно: $availableBonuses бонусов'
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

class _ChoiceCard extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
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
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
