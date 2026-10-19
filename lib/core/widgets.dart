// core/widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/inventory_entry.dart';
import 'app_exception.dart';
import 'app_svgs.dart';
import 'app_theme.dart';
import 'responsive.dart';

import 'package:go_router/go_router.dart';

/// Renders an SVG string from AppSvgs in a single color.
class AppIcon extends StatelessWidget {
  const AppIcon(this.svg, {super.key, this.size = 20, this.color});

  final String svg;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? AppColors.text;
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

/// White rounded card with a thin border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Centers page content and limits its width on big screens.
class PageContainer extends StatelessWidget {
  const PageContainer({super.key, required this.child, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 16 : 28,
            vertical: mobile ? 12 : 24,
          ),
          child: child,
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage(error), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppSvgs.itemsIcon, size: 32, color: AppColors.textSoft),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSoft),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Item image from a URL. Shows a placeholder when empty or broken.
/// Use expand: true inside an AspectRatio to fill the space.
class ItemThumb extends StatelessWidget {
  const ItemThumb({super.key, this.url, this.size = 48, this.expand = false});

  final String? url;
  final double size;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final placeholder = Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: AppIcon(AppSvgs.imageIcon, size: size * 0.4, color: AppColors.textSoft),
        ),
        // if (url != null)
        //   Padding(
        //     padding: EdgeInsetsGeometry.all(10),
        //     child: Text(
        //       url ?? 'N/A',
        //     ),
        //   ),
      ],
    );
    final hasUrl = url != null && url!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(expand ? 14 : size * 0.25),
      child: Container(
        width: expand ? null : size,
        height: expand ? null : size,
        color: AppColors.bg,
        child: hasUrl
            ? Image.network(
                url!,
                fit: BoxFit.contain,
                errorBuilder: (e1, e2, e3) {
                  return placeholder;
                },
              )
            : placeholder,
      ),
    );
  }
}

/// Shows stock quantity. Red when the stock is 0.
class StockBadge extends StatelessWidget {
  const StockBadge(this.quantity, {super.key});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final out = quantity == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: out ? AppColors.dangerSoft : AppColors.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        out ? 'Out of stock' : '$quantity in stock',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: out ? AppColors.danger : AppColors.text,
        ),
      ),
    );
  }
}

extension EntryTypeStyle on EntryType {
  Color get color => switch (this) {
    EntryType.supply => AppColors.success,
    EntryType.sale => AppColors.primary,
    EntryType.manual => AppColors.info,
  };

  Color get softColor => switch (this) {
    EntryType.supply => AppColors.successSoft,
    EntryType.sale => AppColors.primarySoft,
    EntryType.manual => AppColors.infoSoft,
  };

  String get icon => switch (this) {
    EntryType.supply => AppSvgs.supplyIcon,
    EntryType.sale => AppSvgs.saleIcon,
    EntryType.manual => AppSvgs.manualIcon,
  };
}

class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {super.key});

  final EntryType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: type.softColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          color: type.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 3 -> "+3", -4 -> "-4"
String signed(int n) => n > 0 ? '+$n' : '$n';

void showMessage(BuildContext context, String text, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.danger : AppColors.text,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Go back if there is a page to go back to, otherwise open [fallback].
void goBackOr(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Page title row used on the main screens.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: mobile ? 22 : 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(color: AppColors.textSoft),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
