import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/household.dart';
import '../theme.dart';

class HouseholdSwitcherSheet extends StatelessWidget {
  final List<Household> households;
  final String activeCode;
  final ValueChanged<String> onSwitch;
  final VoidCallback onAddHousehold;

  const HouseholdSwitcherSheet({
    super.key,
    required this.households,
    required this.activeCode,
    required this.onSwitch,
    required this.onAddHousehold,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Мои бюджеты',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
            ),
            const SizedBox(height: 16),
            for (final household in households)
              _HouseholdRow(
                household: household,
                isActive: household.code == activeCode,
                onTap: () {
                  Navigator.of(context).pop();
                  if (household.code != activeCode) {
                    onSwitch(household.code);
                  }
                },
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAddHousehold();
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Добавить ещё один бюджет',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdRow extends StatelessWidget {
  final Household household;
  final bool isActive;
  final VoidCallback onTap;

  const _HouseholdRow({
    required this.household,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isActive
            ? kAccentColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kAccentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    color: kAccentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        household.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        household.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  const Icon(Icons.check_circle_rounded, color: kAccentColor)
                else
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: household.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Код скопирован')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
