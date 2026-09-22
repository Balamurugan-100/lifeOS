import 'package:flutter/material.dart';

/// Navigation target for a module that has no dedicated screen yet (T030).
/// Real Tasks/Habits screens replace their own targets in US2/US3; roadmap
/// domains land here until they ship.
class DomainPlaceholderScreen extends StatelessWidget {
  const DomainPlaceholderScreen({super.key, required this.domainTitle});

  final String domainTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(domainTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '$domainTitle is coming soon',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'LifeOS grows one domain at a time — your tasks and habits '
                'are already live.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}