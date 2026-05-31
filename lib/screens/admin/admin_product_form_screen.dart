import 'dart:convert';
import 'dart:io';

import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminProductFormScreen extends StatefulWidget {
  const AdminProductFormScreen({super.key});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _fromKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _weightController = TextEditingController();

  XFile? _image;

  bool _isHit = false;
  bool _isNew = false;
  bool _hasVariants = false;

  final List<_ProductVariantDraft> _variants = [];

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _weightController.dispose();

    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (pickImage == null) return;
    setState(() {
      _image = pickImage;
    });
  }

  void _toggleVariants(bool value) {
    setState(() {
      _hasVariants = value;

      if (_hasVariants && _variants.isEmpty) {
        _variants.addAll([
          _ProductVariantDraft(title: 'Маленькая'),
          _ProductVariantDraft(title: 'Средняя'),
          _ProductVariantDraft(title: 'Большая'),
        ]);
      }
    });
  }

  void _addVariant() {
    setState(() {
      _variants.add(_ProductVariantDraft());
    });
  }

  void _removeVariant(int index) {
    setState(() {
      final removed = _variants.removeAt(index);
      removed.dispose();
    });
  }

  void _saveProduct() {
    final formIsValid = _fromKey.currentState?.validate() ?? false;

    if (!formIsValid) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте картинку товара'),
        ),
      );
      return;
    }

    final productData = {
      'title': _titleController.text.trim(),
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
      'imagePath': _image!.path,
      'isHit': _isHit,
      'isNew': _isNew,
      'hasVariants': _hasVariants,
      if (!_hasVariants) ...{
        'price': int.tryParse(_priceController.text.trim()) ?? 0,
        'weight': _weightController.text.trim(),
      },
      if (_hasVariants)
        'variant': _variants.map((variant) {
          return {
            'title': variant.titleController.text.trim(),
            'price': int.tryParse(variant.priceController.text.trim()) ?? 0,
            'weight': variant.weightController.text.trim(),
          };
        }).toList(),
    };

    debugPrint(
      const JsonEncoder.withIndent(' ').convert(productData),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Товар собран. Данные выведены в debug console.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        backgroundColor: AppColors.header,
        foregroundColor: Colors.white,
        title: const Text(
          'Добавить товар',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _fromKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _SectionCard(
              title: 'Картинка товара',
              child: _ImagePickerBox(
                image: _image,
                onTap: _pickImage,
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Основная информация',
              child: Column(
                children: [
                  _AdminTextField(
                    controller: _titleController,
                    label: 'Название товара',
                    hintText: 'Например: Пицца Злодейка',
                    validatorText: 'Введите название товара',
                  ),
                  const SizedBox(height: 12),
                  _AdminTextField(
                    controller: _categoryController,
                    label: 'Категория',
                    hintText: 'Например: Пицца',
                    validatorText: 'Введите категорию',
                  ),
                  const SizedBox(height: 12),
                  _AdminTextField(
                    controller: _descriptionController,
                    label: 'Описание',
                    hintText: 'Краткое описание товара',
                    maxLines: 4,
                    validatorText: 'Введите описание товара',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Статусы',
              child: Column(
                children: [
                  _SwitchRow(
                    title: 'HOT',
                    subtitle: 'Показывать красную плашку HOT',
                    value: _isHit,
                    onChanged: (value) {
                      setState(() {
                        _isHit = value;
                      });
                    },
                  ),
                  const Divider(height: 20),
                  _SwitchRow(
                    title: 'New',
                    subtitle: 'Показывать зелёную плашку New',
                    value: _isNew,
                    onChanged: (value) {
                      setState(() {
                        _isNew = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Цена и граммовка',
              child: Column(
                children: [
                  _SwitchRow(
                    title: 'Есть варианты размеров',
                    subtitle: 'Например: маленькая, средняя, большая',
                    value: _hasVariants,
                    onChanged: _toggleVariants,
                  ),
                  const SizedBox(height: 14),
                  if (!_hasVariants)
                    Row(
                      children: [
                        Expanded(
                          child: _AdminTextField(
                            controller: _priceController,
                            label: 'Цена',
                            hintText: '450',
                            keyboardType: TextInputType.number,
                            validatorText: 'Введите цену',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _AdminTextField(
                            controller: _weightController,
                            label: 'Вес / объём',
                            hintText: '450 г',
                            validatorText: 'Введите вес',
                          ),
                        ),
                      ],
                    ),
                  if (_hasVariants) ...[
                    for (int i = 0; i < _variants.length; i++) ...[
                      _VariantEditor(
                        variant: _variants[i],
                        onRemove: _variants.length > 1
                            ? () => _removeVariant(i)
                            : null,
                      ),
                      if (i != _variants.length - 1) const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _addVariant,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить вариант'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.header,
                          side: BorderSide(
                            color: AppColors.header.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.header,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Сохранить товар',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  final XFile? image;
  final VoidCallback onTap;

  const _ImagePickerBox({
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.header.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.header.withValues(alpha: 0.12),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(image!.path),
                    fit: BoxFit.cover,
                  ),
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: _SmallDarkBadge(
                      text: 'Изменить фото',
                      icon: Icons.edit,
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 42,
                    color: AppColors.header,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Добавить картинку',
                    style: TextStyle(
                      color: AppColors.header,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Нажмите, чтобы выбрать из галереи',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _VariantEditor extends StatelessWidget {
  final _ProductVariantDraft variant;
  final VoidCallback? onRemove;

  const _VariantEditor({
    required this.variant,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.header.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.header.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AdminTextField(
                  controller: variant.titleController,
                  label: 'Размер',
                  hintText: 'Средняя',
                  validatorText: 'Введите размер',
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdminTextField(
                  controller: variant.priceController,
                  label: 'Цена',
                  hintText: '825',
                  keyboardType: TextInputType.number,
                  validatorText: 'Введите цену',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminTextField(
                  controller: variant.weightController,
                  label: 'Граммовка',
                  hintText: '700 г',
                  validatorText: 'Введите вес',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final String validatorText;
  final int maxLines;
  final TextInputType? keyboardType;

  const _AdminTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.validatorText,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorText;
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.78),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.header,
            width: 1.3,
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.header,
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}

class _SmallDarkBadge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _SmallDarkBadge({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductVariantDraft {
  final TextEditingController titleController;
  final TextEditingController priceController;
  final TextEditingController weightController;

  _ProductVariantDraft({
    String title = '',
    String price = '',
    String weight = '',
  })  : titleController = TextEditingController(text: title),
        priceController = TextEditingController(text: price),
        weightController = TextEditingController(text: weight);

  void dispose() {
    titleController.dispose();
    priceController.dispose();
    weightController.dispose();
  }
}
