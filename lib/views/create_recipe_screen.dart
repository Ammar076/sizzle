import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/recipe_viewmodel.dart';

class CreateRecipeScreen extends ConsumerStatefulWidget {
  /// When [recipe] is provided the screen edits that recipe, otherwise it
  /// creates a new one. When [isCopy] is true the fields are pre-filled from
  /// [recipe] but saved as a brand-new recipe owned by the current user
  /// ("Save a copy").
  final Recipe? recipe;
  final bool isCopy;

  const CreateRecipeScreen({super.key, this.recipe, this.isCopy = false});

  @override
  ConsumerState<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends ConsumerState<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _title;
  late String _description;
  late String _imageUrl;
  late String _category;
  late String _cuisine;
  late String _difficulty;
  late int _prepTime;
  late int _cookTime;
  late int _feeds;

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];

  // Dynamic ingredient / step rows, each backed by its own controller.
  final List<TextEditingController> _ingredients = [];
  final List<TextEditingController> _steps = [];

  File? _pickedImage;
  bool _saving = false;
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  final List<String> _categories = ['Breakfast', 'Lunch', 'Dinner'];

  bool get _isEditing => widget.recipe != null && !widget.isCopy;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _title = widget.isCopy && recipe != null
        ? '${recipe.title} (copy)'
        : recipe?.title ?? '';
    _description = recipe?.description ?? '';
    _imageUrl = recipe?.imageUrl ?? '';
    _category = recipe?.category ?? 'Breakfast';
    if (!_categories.contains(_category)) _category = 'Breakfast';
    _cuisine = recipe?.cuisine ?? '';
    _difficulty = recipe?.difficulty ?? 'Easy';
    if (!_difficulties.contains(_difficulty)) _difficulty = 'Easy';
    _prepTime = recipe?.prepTime ?? 0;
    _cookTime = recipe?.cookTime ?? 0;
    _feeds = recipe?.feeds ?? 1;

    final existingIngredients = recipe?.ingredients ?? const [];
    final existingSteps = recipe?.steps ?? const [];
    for (final ing in existingIngredients) {
      _ingredients.add(TextEditingController(text: ing));
    }
    for (final step in existingSteps) {
      _steps.add(TextEditingController(text: step));
    }
    // Start with one empty row each so the sections aren't blank.
    if (_ingredients.isEmpty) _ingredients.add(TextEditingController());
    if (_steps.isEmpty) _steps.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _ingredients) {
      c.dispose();
    }
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _pickedImage = File(picked.path);
          _dirty = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: Text('Choose from gallery',
                    style: AppText.sans(15, weight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.primary),
                title: Text('Take a photo',
                    style: AppText.sans(15, weight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_pickedImage != null || _imageUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.muted),
                  title: Text('Remove image',
                      style: AppText.sans(15, weight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _pickedImage = null;
                      _imageUrl = '';
                      _dirty = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final ingredients = _ingredients
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final steps =
        _steps.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

    setState(() => _saving = true);
    final notifier = ref.read(recipeViewModelProvider.notifier);

    try {
      var imageUrl = _imageUrl.trim();
      if (_pickedImage != null) {
        final uploadedUrl = await notifier.uploadImage(_pickedImage!);
        if (uploadedUrl != null) imageUrl = uploadedUrl;
      }
      if (imageUrl.isEmpty) {
        imageUrl =
            'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=800&q=80';
      }

      final auth = ref.read(authServiceProvider);
      // A copy (or a brand-new recipe) belongs to the current user and starts
      // with no favorites/ratings/creation time of its own.
      final recipe = Recipe(
        id: _isEditing ? (widget.recipe?.id ?? '') : '',
        title: _title.trim(),
        description: _description.trim(),
        imageUrl: imageUrl,
        category: _category,
        prepTime: _prepTime,
        cookTime: _cookTime,
        feeds: _feeds,
        favoritedBy: _isEditing ? (widget.recipe?.favoritedBy ?? const []) : const [],
        createdAt: _isEditing ? widget.recipe?.createdAt : null,
        authorId: _isEditing
            ? (widget.recipe?.authorId ?? auth.currentUser?.uid)
            : auth.currentUser?.uid,
        authorName: _isEditing
            ? (widget.recipe?.authorName ?? auth.displayName)
            : auth.displayName,
        ingredients: ingredients,
        steps: steps,
        cuisine: _cuisine.trim().isEmpty ? null : _cuisine.trim(),
        difficulty: _difficulty,
      );

      if (_isEditing) {
        await notifier.updateRecipe(recipe);
      } else {
        await notifier.addRecipe(recipe);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isEditing ? 'Recipe updated.' : 'Recipe added to your book.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save recipe: $e')),
      );
    }
  }

  String? _validateInt(String? value, {required int min, int? max}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Required';
    final parsed = int.tryParse(raw);
    if (parsed == null) return 'Numbers only';
    if (parsed < min) return 'Min $min';
    if (max != null && parsed > max) return 'Max $max';
    return null;
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved recipe changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscard();
        if (!context.mounted) return;
        if (shouldLeave) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(widget.isCopy
              ? 'Save a copy'
              : (_isEditing ? 'Edit recipe' : 'New recipe')),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _saving
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _submitForm,
                      child: Text(_isEditing ? 'Save' : 'Add',
                          style: AppText.sans(16,
                              weight: FontWeight.w800,
                              color: AppColors.primary)),
                    ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 26),
                const _SectionTitle('The basics'),
                const SizedBox(height: 14),
                const _Label('Recipe title'),
                TextFormField(
                  initialValue: _title,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Creamy Tomato Pasta'),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter a title';
                    if (v.length < 3) return 'Title is too short';
                    return null;
                  },
                  onSaved: (value) => _title = value!,
                ),
                const SizedBox(height: 20),
                const _Label('Short description'),
                TextFormField(
                  initialValue: _description,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'A quick summary of the dish…',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter a description';
                    if (v.length < 10) {
                      return 'Add a little more detail (10+ characters)';
                    }
                    return null;
                  },
                  onSaved: (value) => _description = value!,
                ),
                const SizedBox(height: 20),
                const _Label('Category'),
                _CategorySelector(
                  categories: _categories,
                  selected: _category,
                  onChanged: (value) => setState(() {
                    _category = value;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 20),
                const _Label('Difficulty'),
                _CategorySelector(
                  categories: _difficulties,
                  selected: _difficulty,
                  onChanged: (value) => setState(() {
                    _difficulty = value;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 20),
                const _Label('Cuisine (optional)'),
                TextFormField(
                  initialValue: _cuisine,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Italian, Yemeni, Mexican'),
                  onSaved: (value) => _cuisine = value ?? '',
                ),
                const SizedBox(height: 20),
                const _Label('Time & servings'),
                _buildNumberFields(),
                const SizedBox(height: 30),
                _buildIngredients(),
                const SizedBox(height: 30),
                _buildSteps(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildIngredients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SectionTitle('Ingredients'),
            const SizedBox(width: 8),
            Text('${_ingredients.length}',
                style: AppText.sans(14,
                    weight: FontWeight.w700, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < _ingredients.length; i++)
          Padding(
            key: ObjectKey(_ingredients[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  height: 8,
                  width: 8,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _ingredients[i],
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        hintText: 'e.g. 2 cups plain flour',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)),
                  ),
                ),
                _RemoveButton(
                  onTap: _ingredients.length == 1
                      ? null
                      : () => setState(() {
                            _ingredients.removeAt(i).dispose();
                            _dirty = true;
                          }),
                ),
              ],
            ),
          ),
        _AddButton(
          label: 'Add ingredient',
          onTap: () => setState(() {
            _ingredients.add(TextEditingController());
            _dirty = true;
          }),
        ),
      ],
    );
  }

  Widget _buildSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Method'),
        const SizedBox(height: 14),
        for (int i = 0; i < _steps.length; i++)
          Padding(
            key: ObjectKey(_steps[i]),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 30,
                  width: 30,
                  margin: const EdgeInsets.only(top: 10, right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.blush,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text('${i + 1}',
                      style: AppText.sans(14,
                          weight: FontWeight.w800,
                          color: AppColors.primaryPressed)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _steps[i],
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        hintText: 'Describe this step…',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)),
                  ),
                ),
                _RemoveButton(
                  onTap: _steps.length == 1
                      ? null
                      : () => setState(() {
                            _steps.removeAt(i).dispose();
                            _dirty = true;
                          }),
                ),
              ],
            ),
          ),
        _AddButton(
          label: 'Add step',
          onTap: () => setState(() {
            _steps.add(TextEditingController());
            _dirty = true;
          }),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        height: 210,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.sage,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.line),
          image: _imagePreview(),
        ),
        child: _hasImage()
            ? Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('Change photo',
                          style: AppText.sans(13,
                              weight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_rounded,
                        color: AppColors.forest, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text('Add a cover photo',
                      style: AppText.sans(15,
                          weight: FontWeight.w700, color: AppColors.forest)),
                  const SizedBox(height: 2),
                  Text('Gallery or camera',
                      style: AppText.sans(13, color: AppColors.forest)),
                ],
              ),
      ),
    );
  }

  bool _hasImage() => _pickedImage != null || _imageUrl.isNotEmpty;

  DecorationImage? _imagePreview() {
    if (_pickedImage != null) {
      return DecorationImage(
          image: FileImage(_pickedImage!), fit: BoxFit.cover);
    }
    if (_imageUrl.isNotEmpty) {
      final provider = _imageUrl.startsWith('http')
          ? NetworkImage(_imageUrl)
          : (_imageUrl.startsWith('/') || _imageUrl.contains(':\\')
              ? FileImage(File(_imageUrl))
              : AssetImage(_imageUrl)) as ImageProvider;
      return DecorationImage(image: provider, fit: BoxFit.cover);
    }
    return null;
  }

  Widget _buildNumberFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 380;
        final prep = _numberField(
          initial: _prepTime,
          hint: 'Prep (min)',
          validator: (v) => _validateInt(v, min: 0, max: 1440),
          onSaved: (v) => _prepTime = int.parse(v!.trim()),
        );
        final cook = _numberField(
          initial: _cookTime,
          hint: 'Cook (min)',
          validator: (v) => _validateInt(v, min: 0, max: 1440),
          onSaved: (v) => _cookTime = int.parse(v!.trim()),
        );
        final feeds = _numberField(
          initial: _feeds,
          hint: 'Serves',
          validator: (v) => _validateInt(v, min: 1, max: 100),
          onSaved: (v) => _feeds = int.parse(v!.trim()),
        );

        if (stack) {
          return Column(
            children: [
              prep,
              const SizedBox(height: 12),
              cook,
              const SizedBox(height: 12),
              feeds,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: prep),
            const SizedBox(width: 12),
            Expanded(child: cook),
            const SizedBox(width: 12),
            Expanded(child: feeds),
          ],
        );
      },
    );
  }

  Widget _numberField({
    required int initial,
    required String hint,
    required String? Function(String?) validator,
    required void Function(String?) onSaved,
  }) {
    return TextFormField(
      initialValue: initial.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: hint),
      validator: validator,
      onSaved: onSaved,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.display(20, weight: FontWeight.w700));
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style:
              AppText.sans(14, weight: FontWeight.w700, color: AppColors.ink)),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _RemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.remove_circle_outline_rounded),
      color: AppColors.muted,
      disabledColor: AppColors.line,
      tooltip: 'Remove',
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;
  const _CategorySelector({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in categories) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c == selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  border: Border.all(
                      color:
                          c == selected ? AppColors.primary : AppColors.line),
                ),
                child: Text(
                  c,
                  style: AppText.sans(14,
                      weight: FontWeight.w700,
                      color: c == selected ? Colors.white : AppColors.ink),
                ),
              ),
            ),
          ),
          if (c != categories.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
