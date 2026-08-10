import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';

class GifPicker extends StatefulWidget {
  final Function(String gifId) onGifSelected;

  const GifPicker({super.key, required this.onGifSelected});

  @override
  State<GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<GifPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _gifs = [];
  bool _isLoading = false;
  String? _error;

  // Giphy API key - Using public beta key (limited usage)
  // For production, replace with your own Giphy API key from developers.giphy.com
  static const String _giphyApiKey = 'sXpGFDGZs0Dv1mmNFvYaGUvYwKX0PWIh';

  @override
  void initState() {
    super.initState();
    _loadTrendingGifs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrendingGifs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.giphy.com/v1/gifs/trending?api_key=$_giphyApiKey&limit=25&rating=g',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['data']);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = context.l10n.gifPicker_failedLoad;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.gifPicker_noInternet;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchGifs(String query) async {
    if (query.trim().isEmpty) {
      _loadTrendingGifs();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.giphy.com/v1/gifs/search?api_key=$_giphyApiKey&q=${Uri.encodeComponent(query)}&limit=25&rating=g',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['data']);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = context.l10n.gifPicker_failedSearch;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.gifPicker_noInternet;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.all(t.spacingMd),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.gif_box, size: 28),
              SizedBox(width: t.spacingXs),
              Text(
                context.l10n.gifPicker_title,
                style: TextStyle(
                  // 03-roles-chrome.md: titleSmall + 7 (default 13+7=20).
                  fontSize:
                      (Theme.of(context).textTheme.titleSmall?.fontSize ?? 13) +
                      7,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: t.spacingMd),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.gifPicker_searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadTrendingGifs();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: t.spacingMd,
                vertical: t.spacingSm,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _searchGifs,
            onChanged: (value) {
              setState(() {}); // Update to show/hide clear button
            },
          ),
          SizedBox(height: t.spacingMd),

          // GIF grid
          Expanded(child: _buildContent()),

          // Powered by Giphy attribution
          SizedBox(height: t.spacingXs),
          Text(
            context.l10n.gifPicker_poweredBy,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final t = MeshTokens.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: t.spacingMd),
            Text(
              _error!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
            SizedBox(height: t.spacingMd),
            ElevatedButton.icon(
              onPressed: _loadTrendingGifs,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.common_retry),
            ),
          ],
        ),
      );
    }

    if (_gifs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: t.spacingMd),
            Text(
              context.l10n.gifPicker_noGifsFound,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: t.spacingXs,
        mainAxisSpacing: t.spacingXs,
        childAspectRatio: 1.0,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final gif = _gifs[index];
        final gifId = gif['id'] as String;
        final previewUrl =
            gif['images']?['fixed_height_small']?['url'] as String?;

        return GestureDetector(
          onTap: () {
            widget.onGifSelected(gifId);
            Navigator.pop(context);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: previewUrl != null
                  ? Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.error_outline));
                      },
                    )
                  : const Center(child: Icon(Icons.gif_box)),
            ),
          ),
        );
      },
    );
  }
}
