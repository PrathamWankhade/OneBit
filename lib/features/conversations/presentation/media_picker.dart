import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F9 — Media picker for selecting images/videos from gallery.
///
/// 3-column grid, multi-select with numbered badges, bottom bar
/// showing count + preview action.
class MediaPicker extends StatefulWidget {
  const MediaPicker({this.maxSelections = 10, super.key});

  final int maxSelections;

  @override
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select media',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _selectedIndices.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selectedIndices.toList()),
            child: Text(
              'Send${_selectedIndices.isNotEmpty ? ' (${_selectedIndices.length})' : ''}',
              style: AppTheme.bodyMedium.copyWith(
                color:
                    _selectedIndices.isEmpty ? AppTheme.textTertiary : AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                _TabButton(label: 'Recent', isActive: true),
                SizedBox(width: 24),
                _TabButton(label: 'Albums', isActive: false),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: 30, // Placeholder count
              itemBuilder: (context, index) => _MediaTile(
                index: index,
                isSelected: _selectedIndices.contains(index),
                selectionOrder: _selectedIndices.contains(index)
                    ? _selectedIndices.toList().indexOf(index) + 1
                    : null,
                onTap: () => _toggleSelection(index),
              ),
            ),
          ),

          // Bottom bar
          if (_selectedIndices.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: AppTheme.bgSurface,
                border: Border(
                  top: BorderSide(color: AppTheme.bgMuted, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Selected: ${_selectedIndices.length} item${_selectedIndices.length == 1 ? '' : 's'}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // TODO: Show preview
                    },
                    child: Text(
                      'Preview',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else if (_selectedIndices.length < widget.maxSelections) {
        _selectedIndices.add(index);
      }
    });
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: AppTheme.bodyMedium.copyWith(
          color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.index,
    required this.isSelected,
    this.selectionOrder,
    required this.onTap,
  });

  final int index;
  final bool isSelected;
  final int? selectionOrder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Placeholder colored tiles to simulate media
    final colors = [
      AppTheme.bgElevated,
      AppTheme.bgOverlay,
      AppTheme.bgMuted,
    ];
    final color = colors[index % colors.length];

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder image
          Container(color: color),

          // Selection indicator
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: selectionOrder != null
                      ? Text(
                          '$selectionOrder',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.bgBase,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const Icon(
                          Icons.check,
                          size: 14,
                          color: AppTheme.bgBase,
                        ),
                ),
              ),
            ),

          // Video indicator (every 3rd tile)
          if (index % 7 == 0 && index > 0)
            const Positioned(
              bottom: 4,
              left: 4,
              child: Icon(
                Icons.videocam,
                size: 16,
                color: AppTheme.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
