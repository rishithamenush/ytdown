import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.loading,
    required this.onSubmit,
    required this.onPaste,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: !loading,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Paste a video link or direct file URL…',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.link_rounded,
              color: AppTheme.brandPrimary,
              size: 20,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 60),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
              IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                tooltip: 'Paste',
                onPressed: onPaste,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
