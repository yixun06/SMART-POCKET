import 'package:flutter/material.dart';

import '../../../core/utils/malaysia_provider_presets.dart';

class ProviderAvatar {
  const ProviderAvatar._();

  static Widget logoWidget(
    BuildContext context,
    MalaysiaProviderPreset preset, {
    double size = 32,
  }) {
    final padding = preset.logoPadding.clamp(0.0, size / 4);
    final innerSize = (size - padding * 2).clamp(0.0, size);

    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: preset.logoAsset == null
              ? Icon(
                  preset.icon,
                  color: preset.color,
                  size: size * 0.62,
                )
              : Image.asset(
                  preset.logoAsset!,
                  width: innerSize,
                  height: innerSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Icon(
                    preset.icon,
                    color: preset.color,
                    size: size * 0.62,
                  ),
                ),
        ),
      ),
    );
  }

  static Widget providerAvatar(
    BuildContext context,
    String providerName, {
    required String type,
    double size = 36,
  }) {
    final preset = MalaysiaProviderPresets.findByName(providerName, type: type);
    if (preset != null) {
      return logoWidget(context, preset, size: size);
    }

    final fallback = MalaysiaProviderPresets.defaultsForType(type);
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Icon(
          fallback.icon,
          color: fallback.color,
          size: size * 0.62,
        ),
      ),
    );
  }
}
