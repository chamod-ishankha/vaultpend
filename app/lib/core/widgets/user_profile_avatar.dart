import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/settings/profile_update_screen.dart';

class UserProfileAvatar extends ConsumerWidget {
  const UserProfileAvatar({
    super.key,
    this.size = 32,
    this.margin,
  });

  final double size;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).value?.user;
    final photo = user?.photoBase64;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileUpdateScreen()),
            );
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: photo != null
                ? Image.memory(
                    base64Decode(photo),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : Icon(Icons.person, size: size * 0.55, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}
