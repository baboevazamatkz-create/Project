import 'package:flutter/material.dart';

import 'data/household_repository.dart';
import 'models/household.dart';
import 'screens/home_screen.dart';
import 'screens/household_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _repository = HouseholdRepository();
  List<Household> _households = [];
  String? _activeCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final households = await _repository.loadHouseholds();
    final activeCode = await _repository.loadActiveCode();
    if (!mounted) return;
    setState(() {
      _households = households;
      _activeCode = households.any((h) => h.code == activeCode)
          ? activeCode
          : (households.isNotEmpty ? households.first.code : null);
      _loading = false;
    });
  }

  Future<void> _onHouseholdReady(Household household) async {
    await _repository.addHousehold(household);
    await _repository.setActiveCode(household.code);
    if (!mounted) return;
    setState(() {
      if (!_households.any((h) => h.code == household.code)) {
        _households = [..._households, household];
      }
      _activeCode = household.code;
    });
  }

  Future<void> _switchHousehold(String code) async {
    await _repository.setActiveCode(code);
    if (!mounted) return;
    setState(() => _activeCode = code);
  }

  void _openAddHouseholdFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HouseholdScreen(
          canCancel: true,
          onReady: (household) async {
            await _onHouseholdReady(household);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final activeCode = _activeCode;
    if (activeCode == null) {
      return HouseholdScreen(onReady: _onHouseholdReady);
    }
    final activeHousehold = _households.firstWhere((h) => h.code == activeCode);
    return HomeScreen(
      household: activeHousehold,
      households: _households,
      onSwitchHousehold: _switchHousehold,
      onAddHousehold: _openAddHouseholdFlow,
    );
  }
}
