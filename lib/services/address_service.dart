import 'package:delycafe/models/address.dart';
import 'package:flutter/material.dart';

class AddressService extends ChangeNotifier {
  final List<Address> _addresses = [];

  List<Address> get addresses => _addresses;

  int _selectedIndex = -1;
  int get selectedIndex => _selectedIndex;

  Address? get selectedAddress =>
      _selectedIndex >= 0 ? _addresses[_selectedIndex] : null;

  void addAddress(Address address) {
    _addresses.add(address);

    if (_selectedIndex == -1) {
      _selectedIndex = 0;
    }

    notifyListeners();
  }

  void removeAddress(int index) {
    _addresses.removeAt(index);

    if (_selectedIndex == index) {
      _selectedIndex = _addresses.isEmpty ? -1 : 0;
    }

    notifyListeners();
  }

  void selectAddress(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}
