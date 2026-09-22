import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/registry.dart';
import '../home/home_controller.dart';

/// Module enable/disable control (T063, FR-005): lists installed domains and
/// lets the user switch them on and off. Disabling never deletes data —
/// re-enabling restores the module's summary exactly (SC-003).
class RegistrySettingsScreen extends ConsumerWidget {
  const RegistrySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registryAsync = ref.watch(moduleRegistryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Modules')),
      body: registryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load modules: $error')),
        data: (registry) {
          final modules = registry.allModules;
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Domains you install appear here. Disabling a module hides it '
                  'from your home overview — its data stays on this device.',
                ),
              ),
              for (final module in modules)
                SwitchListTile(
                  key: Key('module-${module.key}'),
                  title: Text(module.name),
                  subtitle: Text('Enabled: ${registry.isEnabled(module.key)}'),
                  value: registry.isEnabled(module.key),
                  onChanged: (enabled) async {
                    await registry.setEnabled(module.key, enabled);
                    ref.invalidate(moduleRegistryProvider);
                    ref.invalidate(summariesProvider);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}