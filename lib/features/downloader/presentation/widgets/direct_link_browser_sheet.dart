import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/services/direct_link_cookie_store.dart';
import '../../data/services/direct_link_http_profile.dart';

class DirectLinkBrowserSheet extends StatefulWidget {
  const DirectLinkBrowserSheet({
    super.key,
    required this.fileUrl,
    required this.cookieStore,
  });

  final String fileUrl;
  final DirectLinkCookieStore cookieStore;

  @override
  State<DirectLinkBrowserSheet> createState() => _DirectLinkBrowserSheetState();
}

class _DirectLinkBrowserSheetState extends State<DirectLinkBrowserSheet> {
  late final WebUri _originUrl;
  InAppWebViewController? _webController;
  var _pageReady = false;
  var _saving = false;
  var _loadedFileUrl = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse(widget.fileUrl);
    _originUrl = WebUri('${uri.scheme}://${uri.host}/');
  }

  Future<void> _saveCookiesAndClose() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final host = Uri.parse(widget.fileUrl).host;
      final fileUri = WebUri(widget.fileUrl);

      // Collect cookies for both the site root and the file URL.
      final seen = <String>{};
      final parts = <String>[];
      for (final url in [_originUrl, fileUri]) {
        final cookies = await CookieManager.instance().getCookies(url: url);
        for (final c in cookies) {
          final pair = '${c.name}=${c.value}';
          if (seen.add(pair)) parts.add(pair);
        }
      }

      if (parts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No session yet — wait for the page to finish loading, '
              'complete any security check, then tap Continue.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      widget.cookieStore.save(host, parts.join('; '));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.parse(widget.fileUrl).host;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verify $host',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete any security check below, then tap '
                            'Continue to download in Vidoory.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(url: _originUrl),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        thirdPartyCookiesEnabled: true,
                        userAgent: DirectLinkHttpProfile.userAgent,
                        useShouldOverrideUrlLoading: true,
                        allowsInlineMediaPlayback: true,
                      ),
                      onWebViewCreated: (c) => _webController = c,
                      onLoadStop: (controller, _) async {
                        // Visit the site root first, then the file URL so CDN
                        // cookies (e.g. Cloudflare) apply to the download host.
                        if (!_loadedFileUrl) {
                          _loadedFileUrl = true;
                          await controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(widget.fileUrl),
                            ),
                          );
                          return;
                        }
                        if (mounted) setState(() => _pageReady = true);
                      },
                    ),
                    if (!_pageReady)
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _pageReady = false;
                                  _loadedFileUrl = false;
                                });
                                _webController?.loadUrl(
                                  urlRequest: URLRequest(url: _originUrl),
                                );
                              },
                        child: const Text('Reload'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed:
                            _saving || !_pageReady ? null : _saveCookiesAndClose,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Continue',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
