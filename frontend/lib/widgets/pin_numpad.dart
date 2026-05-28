import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PinNumpad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  /// Optional widget in bottom-right slot (e.g. fingerprint button).
  /// Pass null to leave the slot empty.
  final Widget? rightAction;

  const PinNumpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(['1', '2', '3']),
        const SizedBox(height: 14),
        _row(['4', '5', '6']),
        const SizedBox(height: 14),
        _row(['7', '8', '9']),
        const SizedBox(height: 14),
        _bottomRow(),
      ],
    );
  }

  Widget _row(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits
          .map((d) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _DigitKey(digit: d, onTap: () => onDigit(d)),
              ))
          .toList(),
    );
  }

  Widget _bottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _BackspaceKey(onTap: onBackspace),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _DigitKey(digit: '0', onTap: () => onDigit('0')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            width: 72,
            height: 72,
            child: rightAction,
          ),
        ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _DigitKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
              fontFamily: 'IBMPlexMono',
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final VoidCallback onTap;

  const _BackspaceKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppColors.inkSoft,
            size: 26,
          ),
        ),
      ),
    );
  }
}
