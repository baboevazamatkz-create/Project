import 'package:flutter/material.dart';

import 'data/household_repository.dart';
import 'screens/home_screen.dart';
import 'screens/household_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _repository = HouseholdRepository();
  String? _householdCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHouseholdCode();
  }

  Future<void> _loadHouseholdCode() async {
    final code = await _repository.loadHouseholdCode();
    if (!mounted) return;
    setState(() {
      _householdCode = code;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final code = _householdCode;
    if (code == null) {
      return HouseholdScreen(
        onReady: (newCode) => setState(() => _householdCode = newCode),
      );
    }
    return HomeScreen(householdCode: code);
  }
}
