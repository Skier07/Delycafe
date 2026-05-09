import 'package:delycafe/models/address.dart';
import 'package:delycafe/services/address_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final addressService = context.watch<AddressService>();
    final addresses = addressService.addresses;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            children: [
              // Список
              Expanded(
                child: addresses.isEmpty
                    ? const Center(child: Text('Нет адресов'))
                    : ListView.builder(
                        itemCount: addresses.length,
                        itemBuilder: (context, index) {
                          final addr = addresses[index];
                          final isSelected =
                              index == addressService.selectedIndex;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.header.withValues(alpha: 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                // Текст
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      addressService.selectAddress(index);
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          addr.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(addr.address),
                                      ],
                                    ),
                                  ),
                                ),

                                //Удалить
                                IconButton(
                                  onPressed: () {
                                    addressService.removeAddress(index);
                                  },
                                  icon: const Icon(Icons.delete),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),

              // Кнопка добавить
              SizedBox(
                width: double.infinity,
                child: AuthButton(
                  onPressed: () {
                    _showAddDialog(context);
                  },
                  text: 'Добавить адрес',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext contex) {
    final titleController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: contex,
      builder: (_) {
        return AlertDialog(
          title: const Text('Новый адрес'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Адрес'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contex),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isEmpty ||
                    addressController.text.isEmpty) return;

                contex.read<AddressService>().addAddress(
                      Address(
                        title: titleController.text,
                        address: addressController.text,
                      ),
                    );
                Navigator.pop(contex);
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }
}
