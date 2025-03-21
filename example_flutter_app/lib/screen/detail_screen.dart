// lib/screens/detail_screen.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../model/api_error.dart';
import '../model/image_detail.dart';
import '../model/image_result.dart';
import '../service/image_service.dart';

class DetailScreen extends StatefulWidget {

  const DetailScreen({
    super.key,
    required this.image,
  });

  final ImageResult image;

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ImageService _imageService = ImageService();

  // State variables
  bool _isLoading = true;
  String _errorMessage = '';
  ImageDetails? _imageDetails;
  List<ImageResult> _relatedImages = [];
  bool _isLoadingRelated = false;

  // Cancel tokens
  final Map<String, CancelToken> _cancelTokens = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Cancel all pending requests when navigating away
    _cancelTokens.forEach((key, token) {
      if (!token.isCancelled) {
        token.cancel('User navigated away');
      }
    });
    super.dispose();
  }

  // Load all data
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _fetchImageDetails();

      // Only fetch related images if details were successfully loaded
      if (_imageDetails != null) {
        await _fetchRelatedImages();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e is ApiError
            ? e.message
            : 'Failed to load image details. Please try again.';
      });
    }
  }

  // Fetch detailed image information
  Future<void> _fetchImageDetails() async {
    final token = CancelToken();
    _cancelTokens['details'] = token;

    try {
      final imageDetails = await _imageService.getImageDetails(
        id: widget.image.id,
        cancelToken: token,
      );

      setState(() {
        _imageDetails = imageDetails;
      });
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        throw e;
      }
    }
  }

  // Fetch related images
  Future<void> _fetchRelatedImages() async {
    setState(() {
      _isLoadingRelated = true;
    });

    final token = CancelToken();
    _cancelTokens['related'] = token;

    try {
      final relatedImages = await _imageService.getRelatedImages(
        id: widget.image.id,
        cancelToken: token,
      );

      setState(() {
        _relatedImages = relatedImages;
        _isLoadingRelated = false;
      });
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        setState(() {
          _isLoadingRelated = false;
        });
        // We don't want to fail the entire load if just related images fail
        print('Failed to load related images: ${e.message}');
      }
    }
  }

  // Download image (in a real app, would save to device)
  Future<void> _downloadImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting download...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final token = CancelToken();
      _cancelTokens['download'] = token;

      final downloadUrl = await _imageService.trackDownload(
        id: widget.image.id,
        cancelToken: token,
      );

      // In a real app, you would use a package like flutter_downloader
      // to save the image to the device.
      // For this example, we'll just show a success message

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image downloaded successfully'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Open the downloaded file
              print('Download URL: $downloadUrl');
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiError
                ? e.message
                : 'Failed to download image. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Share image URL
  void _shareImage() {
    // In a real app, you would use a package like share_plus
    // to share the image URL
    final url = widget.image.urls.full;

    // For this example, copy to clipboard and show a snackbar
    Clipboard.setData(ClipboardData(text: url)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image URL copied to clipboard'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? _buildErrorView()
          : _buildDetailContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _downloadImage,
        child: const Icon(Icons.download),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareImage,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'image-${widget.image.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      widget.image.urls.regular,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              widget.image.urls.small,
                              fit: BoxFit.cover,
                            ),
                            Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    // Gradient overlay for better text visibility
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Image info overlay
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_imageDetails?.description?.isNotEmpty ?? false)
                            Text(
                              _imageDetails!.description!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundImage: NetworkImage(
                                  widget.image.user.profileImage.small,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.image.user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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
            ),
          ),
        ];
      },
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Image info
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About this photo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_imageDetails?.description?.isNotEmpty ?? false) ...[
                      Text(
                        _imageDetails!.description!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_imageDetails?.altDescription?.isNotEmpty ?? false) ...[
                      Text(
                        _imageDetails!.altDescription!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_imageDetails?.location != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _imageDetails!.location!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(widget.image.createdAt),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Image statistics
            if (_imageDetails?.statistics != null)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.download_outlined,
                            count: _imageDetails!.statistics!.downloads,
                            label: 'Downloads',
                          ),
                          _buildStatItem(
                            icon: Icons.visibility_outlined,
                            count: _imageDetails!.statistics!.views,
                            label: 'Views',
                          ),
                          _buildStatItem(
                            icon: Icons.favorite_outline,
                            count: _imageDetails!.statistics!.likes,
                            label: 'Likes',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Tags
            if (_imageDetails?.tags != null && _imageDetails!.tags!.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tags',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _imageDetails!.tags!.map((tag) {
                          return Chip(
                            label: Text(tag.title),
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Photographer info
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photographer',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(
                            widget.image.user.profileImage.medium,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.image.user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text('@${widget.image.user.username}'),
                              if (widget.image.user.location != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14),
                                    const SizedBox(width: 4),
                                    Text(widget.image.user.location!),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.image.user.bio != null && widget.image.user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.image.user.bio!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.photo_library_outlined,
                          count: widget.image.user.totalPhotos,
                          label: 'Photos',
                        ),
                        _buildStatItem(
                          icon: Icons.favorite_outline,
                          count: widget.image.user.totalLikes,
                          label: 'Likes',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Related images
            if (_relatedImages.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Related Images',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _buildRelatedImagesGrid(),
              const SizedBox(height: 16),
            ] else if (_isLoadingRelated) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build stat item with icon, count and label
  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          _formatNumber(count),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Build related images grid
  Widget _buildRelatedImagesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _relatedImages.length,
      itemBuilder: (context, index) {
        final image = _relatedImages[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(image: image),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
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
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                    child: Text(
                      image.user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for date formatting
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper method for number formatting
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}