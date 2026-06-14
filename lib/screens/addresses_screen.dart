import 'package:delycafe/models/customer_address.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/customer_api_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final CustomerApiService _customerApiService = CustomerApiService();

  bool _isLoading = false;
  String? _errorMessage;
  List<CustomerAddress> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final user = context.read<AuthService>().currentUser;

    if (user == null) {
      setState(() {
        _addresses = [];
        _errorMessage = 'Пользователь не авторизован';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final addresses = await _customerApiService.fetchAddresses(
        phone: user.phone,
      );

      if (!mounted) return;

      setState(() {
        _addresses = addresses;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshProfile() async {
    await context.read<AuthService>().refreshCurrentUser();
  }

  Future<void> _openAddressForm({
    CustomerAddress? address,
  }) async {
    final user = context.read<AuthService>().currentUser;

    if (user == null) {
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _AddressFormSheet(
          initialAddress: address,
          onSubmit: ({
            required title,
            required addressText,
            required entrance,
            required floor,
            required apartment,
            required comment,
            required isDefault,
          }) async {
            if (address == null) {
              await _customerApiService.createAddress(
                phone: user.phone,
                title: title,
                address: addressText,
                entrance: entrance,
                floor: floor,
                apartment: apartment,
                comment: comment,
                isDefault: isDefault,
              );
            } else {
              await _customerApiService.updateAddress(
                addressId: address.id,
                title: title,
                address: addressText,
                entrance: entrance,
                floor: floor,
                apartment: apartment,
                comment: comment,
                isDefault: isDefault,
              );
            }

            await _refreshProfile();
          },
        );
      },
    );

    if (result == true) {
      await _loadAddresses();
    }
  }

  Future<void> _setDefaultAddress(CustomerAddress address) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _customerApiService.setDefaultAddress(
        addressId: address.id,
      );

      await _refreshProfile();
      await _loadAddresses();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось выбрать адрес: $error'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAddress(CustomerAddress address) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить адрес?'),
          content: Text(address.fullAddress),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _customerApiService.deleteAddress(
        addressId: address.id,
      );

      await _refreshProfile();
      await _loadAddresses();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось удалить адрес: $error'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        elevation: 0,
        toolbarHeight: 76,
        titleSpacing: 16,
        title: Row(
          children: [
            ShaderGlassContainer(
              borderRadius: 30,
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                CupertinoIcons.chevron_left_2,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Адреса доставки',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openAddressForm();
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAddresses,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user == null)
              const _EmptyState(
                title: 'Вы не авторизованы',
                subtitle: 'Войдите по номеру телефона, чтобы сохранить адреса.',
              )
            else if (_isLoading && _addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              _EmptyState(
                title: 'Не удалось загрузить адреса',
                subtitle: _errorMessage!,
              )
            else if (_addresses.isEmpty)
              const _EmptyState(
                title: 'Адресов пока нет',
                subtitle:
                    'Добавьте адрес, и он будет подставляться при оформлении заказа.',
              )
            else
              ..._addresses.map(
                (address) {
                  return _AddressCard(
                    address: address,
                    onTap: () {
                      _openAddressForm(address: address);
                    },
                    onSetDefault: () {
                      _setDefaultAddress(address);
                    },
                    onDelete: () {
                      _deleteAddress(address);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final CustomerAddress address;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.onTap,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address.title.isEmpty ? 'Адрес' : address.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (address.isDefault)
                    const Chip(
                      label: Text('По умолчанию'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                address.fullAddress.isNotEmpty
                    ? address.fullAddress
                    : address.address,
                style: const TextStyle(
                  fontSize: 15,
                ),
              ),
              if (address.comment.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  address.comment,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!address.isDefault)
                    TextButton(
                      onPressed: onSetDefault,
                      child: const Text('Выбрать основным'),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final CustomerAddress? initialAddress;
  final Future<void> Function({
    required String title,
    required String addressText,
    required String entrance,
    required String floor,
    required String apartment,
    required String comment,
    required bool isDefault,
  }) onSubmit;

  const _AddressFormSheet({
    required this.initialAddress,
    required this.onSubmit,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _addressController;
  late final TextEditingController _entranceController;
  late final TextEditingController _floorController;
  late final TextEditingController _apartmentController;
  late final TextEditingController _commentController;

  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final address = widget.initialAddress;

    _titleController = TextEditingController(
      text: address?.title ?? 'Дом',
    );
    _addressController = TextEditingController(
      text: address?.address ?? '',
    );
    _entranceController = TextEditingController(
      text: address?.entrance ?? '',
    );
    _floorController = TextEditingController(
      text: address?.floor ?? '',
    );
    _apartmentController = TextEditingController(
      text: address?.apartment ?? '',
    );
    _commentController = TextEditingController(
      text: address?.comment ?? '',
    );

    _isDefault = address?.isDefault ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _entranceController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    _commentController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSubmit(
        title: _titleController.text.trim(),
        addressText: _addressController.text.trim(),
        entrance: _entranceController.text.trim(),
        floor: _floorController.text.trim(),
        apartment: _apartmentController.text.trim(),
        comment: _commentController.text.trim(),
        isDefault: _isDefault,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить адрес: $error'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initialAddress == null
                    ? 'Новый адрес'
                    : 'Редактировать адрес',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Дом, работа, к маме',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Адрес',
                  hintText: 'Озёрск, ул. Ленина, 1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите адрес';
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
                      decoration: const InputDecoration(
                        labelText: 'Подъезд',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _floorController,
                      decoration: const InputDecoration(
                        labelText: 'Этаж',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _apartmentController,
                      decoration: const InputDecoration(
                        labelText: 'Кв.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  hintText: 'Домофон, ориентир, пожелания',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              SwitchListTile(
                value: _isDefault,
                onChanged: (value) {
                  setState(() {
                    _isDefault = value;
                  });
                },
                title: const Text('Использовать по умолчанию'),
              ),
              const SizedBox(height: 12),
              AuthButton(
                onPressed: _isSaving ? null : _submit,
                text: _isSaving ? 'Сохраняем...' : 'Сохранить адрес',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
