// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../model/api_error.dart';
import '../model/image_result.dart';
import '../model/models.dart';
import '../service/image_service.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Image service
  final ImageService _imageService = ImageService();

  // Search debouncing
  Timer? _debounce;
  final _searchController = TextEditingController();

  // State variables
  List<ImageResult> _images = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  int _page = 1;
  bool _hasMore = true;
  final int _perPage = 30;
  String _searchQuery = '';
  String _selectedColor = '';
  String _selectedOrientation = '';

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  // Cancel token for cancelling requests
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();

    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);

    // Load trending images on startup
    _loadTrendingImages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();

    // Cancel any pending requests
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User navigated away');
    }

    super.dispose();
  }

  // Scroll listener for infinite scrolling
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreImages();
      }
    }
  }

  // Search with debouncing
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty && query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _page = 1;
        });
        _searchImages(query);
      } else if (query.trim().isEmpty) {
        setState(() {
          _searchQuery = '';
          _page = 1;
        });
        _loadTrendingImages();
      }
    });
  }

  // Load trending images
  Future<void> _loadTrendingImages() async {
    // Cancel previous request if any
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('New request initiated');
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _images = [];
      _cancelToken = CancelToken();
    });

    try {
      final images = await _imageService.getTrendingImages(
        page: _page,
        perPage: _perPage,
        cancelToken: _cancelToken,
      );

      setState(() {
        _images = images;
        _isLoading = false;
        _hasMore = images.length == _perPage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e is ApiError
            ? e.message
            : 'Failed to load images. Please try again.';
      });
    }
  }

  // Search for images
  Future<void> _searchImages(String query) async {
    // Cancel previous request if any
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('New search initiated');
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _images = [];
      _cancelToken = CancelToken();
    });

    try {
      final searchResponse = await _imageService.searchImages(
        query: query,
        page: _page,
        perPage: _perPage,
        color: _selectedColor.isNotEmpty ? _selectedColor : null,
        orientation: _selectedOrientation.isNotEmpty ? _selectedOrientation : null,
        cancelToken: _cancelToken,
      );

      setState(() {
        _images = searchResponse.results;
        _isLoading = false;
        _hasMore = _page < searchResponse.totalPages;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e is ApiError
            ? e.message
            : 'Failed to search images. Please try again.';
      });
    }
  }

  // Load more images for pagination
  Future<void> _loadMoreImages() async {
    setState(() {
      _isLoadingMore = true;
      _page++;
    });

    try {
      if (_searchQuery.isEmpty) {
        // Load more trending images
        final images = await _imageService.getTrendingImages(
          page: _page,
          perPage: _perPage,
        );

        setState(() {
          _images.addAll(images);
          _isLoadingMore = false;
          _hasMore = images.length == _perPage;
        });
      } else {
        // Load more search results
        final searchResponse = await _imageService.searchImages(
          query: _searchQuery,
          page: _page,
          perPage: _perPage,
          color: _selectedColor.isNotEmpty ? _selectedColor : null,
          orientation: _selectedOrientation.isNotEmpty ? _selectedOrientation : null,
        );

        setState(() {
          _images.addAll(searchResponse.results);
          _isLoadingMore = false;
          _hasMore = _page < searchResponse.totalPages;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _page--; // Revert page increment on failure
        _errorMessage = e is ApiError
            ? e.message
            : 'Failed to load more images. Please try again.';
      });
    }
  }

  // Show filter dialog
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Color',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildColorFilterChip('', 'Any', setModalState),
                    _buildColorFilterChip('black_and_white', 'B&W', setModalState),
                    _buildColorFilterChip('black', 'Black', setModalState),
                    _buildColorFilterChip('white', 'White', setModalState),
                    _buildColorFilterChip('yellow', 'Yellow', setModalState),
                    _buildColorFilterChip('orange', 'Orange', setModalState),
                    _buildColorFilterChip('red', 'Red', setModalState),
                    _buildColorFilterChip('purple', 'Purple', setModalState),
                    _buildColorFilterChip('magenta', 'Magenta', setModalState),
                    _buildColorFilterChip('green', 'Green', setModalState),
                    _buildColorFilterChip('teal', 'Teal', setModalState),
                    _buildColorFilterChip('blue', 'Blue', setModalState),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Orientation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildOrientationFilterChip('', 'Any', setModalState),
                    _buildOrientationFilterChip('landscape', 'Landscape', setModalState),
                    _buildOrientationFilterChip('portrait', 'Portrait', setModalState),
                    _buildOrientationFilterChip('squarish', 'Square', setModalState),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (_searchQuery.isNotEmpty) {
                        setState(() {
                          _page = 1;
                        });
                        _searchImages(_searchQuery);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Build color filter chip
  Widget _buildColorFilterChip(String value, String label, StateSetter setModalState) {
    return FilterChip(
      label: Text(label),
      selected: _selectedColor == value,
      onSelected: (selected) {
        setModalState(() {
          _selectedColor = selected ? value : '';
        });
      },
      // Show color preview in avatar for color chips
      avatar: value.isNotEmpty && value != 'black_and_white'
          ? CircleAvatar(
        backgroundColor: _getColorFromString(value),
        radius: 8,
      )
          : value == 'black_and_white'
          ? const CircleAvatar(
        backgroundColor: Colors.grey,
        radius: 8,
      )
          : null,
    );
  }

  // Build orientation filter chip
  Widget _buildOrientationFilterChip(String value, String label, StateSetter setModalState) {
    return FilterChip(
      label: Text(label),
      selected: _selectedOrientation == value,
      onSelected: (selected) {
        setModalState(() {
          _selectedOrientation = selected ? value : '';
        });
      },
      // Show orientation icon
      avatar: value.isNotEmpty
          ? Icon(
        value == 'landscape'
            ? Icons.crop_landscape
            : value == 'portrait'
            ? Icons.crop_portrait
            : Icons.crop_square,
        size: 16,
      )
          : null,
    );
  }

  // Convert string to color
  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'purple':
        return Colors.purple;
      case 'magenta':
        return Colors.pink;
      case 'green':
        return Colors.green;
      case 'teal':
        return Colors.teal;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Navigate to image details
  void _navigateToDetails(ImageResult image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(image: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverAppBar(
                title: const Text('Image Search'),
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilterDialog,
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _searchQuery.isEmpty
                                ? 'Trending Images'
                                : 'Search Results',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_searchQuery.isNotEmpty || _selectedColor.isNotEmpty || _selectedOrientation.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _selectedColor = '';
                                  _selectedOrientation = '';
                                  _searchController.clear();
                                  _page = 1;
                                });
                                _loadTrendingImages();
                              },
                              child: const Text('Clear All'),
                            ),
                        ],
                      ),
                      if (_errorMessage.isNotEmpty) _buildErrorMessage(),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: _isLoading && _images.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _images.isEmpty && _errorMessage.isEmpty
              ? _buildEmptyState()
              : _buildImageGrid(),
        ),
      ),
    );
  }

  // Build search bar
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(50),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for images...',
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _page = 1;
              });
              _loadTrendingImages();
            },
          )
              : null,
        ),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            setState(() {
              _searchQuery = value;
              _page = 1;
            });
            _searchImages(value);
          }
        },
      ),
    );
  }

  // Build error message display
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_search,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No trending images available'
                : 'No images found for "$_searchQuery"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Build image grid
  Widget _buildImageGrid() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_searchQuery.isEmpty) {
          await _loadTrendingImages();
        } else {
          await _searchImages(_searchQuery);
        }
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: _images.length + (_isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _images.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final image = _images[index];
          return GestureDetector(
            onTap: () => _navigateToDetails(image),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  Hero(
                    tag: 'image-${image.id}',
                    child: Image.network(
                      image.urls.small,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 40),
                          ),
                        );
                      },
                    ),
                  ),

                  // Gradient overlay at the bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Image info
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          image.user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(image.likes),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper method to format numbers
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}