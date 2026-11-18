import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/discover/view/plugin_order_dialog.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.read<PluginRegistryCubit>();
    return BlocProvider(
      create: (_) => DiscoverCubit(registry: registry)..load(),
      child: const _DiscoverView(),
    );
  }
}

class _DiscoverView extends StatelessWidget {
  const _DiscoverView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.discover.title),
        actions: [
          IconButton(
            tooltip: t.discover.customOrder,
            icon: const Icon(Icons.reorder),
            onPressed: () => showPluginOrderDialog(context),
          ),
          IconButton(
            tooltip: t.discover.search,
            icon: const Icon(Icons.search),
            onPressed: () => _search(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: RefreshIndicator(
        onRefresh: () => context.read<DiscoverCubit>().reload(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildPluginHome(context),
          ),
        ),
      ),
      floatingActionButtonLocation:
          context.watch<GlobalSettingCubit>().state.leftHandModeEnabled
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: t.discover.search,
        onPressed: () => _search(context),
        child: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildPluginHome(BuildContext context) {
    return BlocBuilder<DiscoverCubit, DiscoverState>(
      builder: (context, state) {
        final plugins = state.plugins.values.toList();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const SizedBox(height: 16),
            _buildPluginStoreButton(context),
            const SizedBox(height: 8),
            _buildSectionHeader(context, t.discover.pluginManagement),
            if (plugins.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    t.discover.noPlugins,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              for (final plugin in plugins) ...[
                _buildPluginCard(context, plugin, state),
              ],
          ],
        );
      },
    );
  }

  Widget _buildPluginCard(
    BuildContext context,
    PluginRuntimeState plugin,
    DiscoverState state,
  ) {
    final cubit = context.read<DiscoverCubit>();
    final info = state.infos[plugin.uuid];
    final error = state.infoErrors[plugin.uuid];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: PluginCard(
        pluginUuid: plugin.uuid,
        pluginState: plugin,
        info: info,
        error: error,
        isToggling: state.togglingUuids.contains(plugin.uuid),
        onSearch: () => _openPluginSearch(context, plugin.uuid),
        onSettings: (title) => _openPluginSettings(context, plugin.uuid, title),
        onToggleEnabled: (enabled) => cubit.toggleEnabled(plugin.uuid, enabled),
        onRetry: () => cubit.retryLoadInfo(plugin.uuid),
        onAction: (action) => DiscoverRouter.route(
          context,
          action: DiscoverRouter.attachSource(action, plugin.uuid),
          currentFrom: cubit.currentFrom,
        ),
      ),
    );
  }

  /// 插件商店需要口令才能进入。
  Future<void> _openPluginStore(BuildContext context) async {
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (_) => const _PluginStorePasswordDialog(),
    );
    if (unlocked == true && context.mounted) {
      context.pushRoute(const PluginStoreRoute());
    }
  }

  Widget _buildPluginStoreButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _openPluginStore(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 22,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.discover.pluginStore,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              t.discover.browseInstall,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openPluginSearch(BuildContext context, String from) {
    final source = from.trim();
    if (source.isEmpty) {
      showErrorToast(t.error.missingPluginSource(action: t.discover.search));
      return;
    }
    context.pushRoute(
      SearchRoute(
        searchState: SearchStates.initial().copyWith(from: source),
        aggregateMode: false,
      ),
    );
  }

  void _openPluginSettings(BuildContext context, String uuid, String title) {
    context.pushRoute(
      PluginSettingsRoute(
        from: uuid,
        pluginUuid: uuid,
        pluginRuntimeName: uuid,
        pluginDisplayName: title,
      ),
    );
  }

  void _search(BuildContext context) {
    final cubit = context.read<DiscoverCubit>();
    final source = cubit.currentFrom;
    if (source.isEmpty) {
      showErrorToast(t.discover.noPluginForSearch);
      return;
    }
    context.pushRoute(
      SearchRoute(
        searchState: SearchStates.initial().copyWith(from: source),
        aggregateMode: true,
      ),
    );
  }
}

/// 进入插件商店前的口令弹窗。
class _PluginStorePasswordDialog extends StatefulWidget {
  const _PluginStorePasswordDialog();

  @override
  State<_PluginStorePasswordDialog> createState() =>
      _PluginStorePasswordDialogState();
}

class _PluginStorePasswordDialogState
    extends State<_PluginStorePasswordDialog> {
  static const String _password = '333';

  final TextEditingController _controller = TextEditingController();
  bool _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim() == _password) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _hasError = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.discover.pluginStore),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '访问密码',
          errorText: _hasError ? '密码错误' : null,
        ),
        onChanged: (_) {
          if (_hasError) {
            setState(() => _hasError = false);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
