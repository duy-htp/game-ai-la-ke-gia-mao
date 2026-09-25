import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../domain/avatar_catalog.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const screenKey = Key('onboarding-screen');

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _usernameController = TextEditingController();
  String _selectedAvatarId = AvatarCatalog.options.first.id;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(appSessionControllerProvider);
    final needsProfile = state is AppSessionNeedsProfile ? state : null;

    return Scaffold(
      key: OnboardingScreen.screenKey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.gameTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: AppColors.gold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      l10n.chooseYourName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('username-field'),
                      controller: _usernameController,
                      enabled: !(needsProfile?.isSubmitting ?? false),
                      maxLength: 20,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.displayName,
                        hintText: l10n.usernameHint,
                        filled: true,
                        fillColor: AppColors.navy800,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.chooseAvatar,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemCount: AvatarCatalog.options.length,
                      itemBuilder: (context, index) {
                        final avatar = AvatarCatalog.options[index];
                        final selected = avatar.id == _selectedAvatarId;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: l10n.avatarOption(index + 1),
                          child: InkWell(
                            key: Key('avatar-${avatar.id}'),
                            borderRadius: BorderRadius.circular(20),
                            onTap: needsProfile?.isSubmitting ?? false
                                ? null
                                : () => setState(
                                    () => _selectedAvatarId = avatar.id,
                                  ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              decoration: BoxDecoration(
                                color: AppColors.navy800,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.gold
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                avatar.emoji,
                                style: const TextStyle(fontSize: 31),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (needsProfile?.submissionError case final error?) ...[
                      const SizedBox(height: 18),
                      Text(
                        ErrorMessageMapper.localize(error, l10n),
                        key: const Key('onboarding-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      key: const Key('complete-profile-button'),
                      onPressed:
                          needsProfile == null || needsProfile.isSubmitting
                          ? null
                          : () => ref
                                .read(appSessionControllerProvider.notifier)
                                .completeProfile(
                                  username: _usernameController.text,
                                  avatarId: _selectedAvatarId,
                                ),
                      child: needsProfile?.isSubmitting ?? false
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(l10n.startPlaying),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
