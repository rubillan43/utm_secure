import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

const _maroon = Color(0xFF800000);

const _categories = [
  'Electronics',
  'Clothing',
  'Accessories',
  'Books / Stationery',
  'Keys',
  'Bags',
  'ID / Cards',
  'Other',
];

// ─────────────────────────────────────────────────────────────
// UTM JB Location data
// ─────────────────────────────────────────────────────────────
class _Loc {
  final String code;
  final String group;
  const _Loc(this.code, this.group);

  /// What gets saved to Firestore and displayed in the field
  String get display => '$code — $group';

  bool matches(String query) {
    final q = query.toLowerCase();
    return code.toLowerCase().contains(q) || group.toLowerCase().contains(q);
  }
}

List<_Loc> _buildLocations() {
  String pad(int n) => n.toString().padLeft(2, '0');
  return [
    // ── Colleges ──────────────────────────────────────────────────────────────
    const _Loc('KRP', 'Kolej Raja Perempuan Zarith Sofiah'),
    const _Loc('KTF', 'Kolej Tun Fatimah'),
    const _Loc('KTR', 'Kolej Tun Razak'),
    const _Loc('KTHO', 'Kolej Tun Hussein Onn'),
    const _Loc('KTDI', 'Kolej Tun Dr Ismail'),
    const _Loc('KTC', 'Kolej Tun Razak Cawangan'),
    const _Loc('KP', 'Kolej Perdana'),
    const _Loc('K9 & K10', 'Kolej 9 & Kolej 10'),
    const _Loc('KDSE', 'Kolej Datin Seri Endon'),
    _Loc('KDOJ', "Kolej Dato' Onn Jaafar"),
    // ── Faculty of Science (C01–C22) ──────────────────────────────────────────
    for (int i = 1; i <= 22; i++) _Loc('C${pad(i)}', 'Faculty of Science'),
    // ── Mechanical Engineering (E01–E07) ──────────────────────────────────────
    for (int i = 1; i <= 7; i++) _Loc('E${pad(i)}', 'Mechanical Engineering'),
    // ── Faculty of Computing ──────────────────────────────────────────────────
    const _Loc('N28', 'Faculty of Computing'),
    for (int i = 1; i <= 5; i++) _Loc('F${pad(i)}', 'Faculty of Computing'),
    // ── Civil Engineering (M01–M50) ───────────────────────────────────────────
    for (int i = 1; i <= 50; i++) _Loc('M${pad(i)}', 'Civil Engineering'),
    // ── Electrical Engineering ────────────────────────────────────────────────
    const _Loc('P19', 'Electrical Engineering'),
    // ── Management / Language ─────────────────────────────────────────────────
    const _Loc('F54', 'Management & Language Faculty'),
    // ── Lecture Halls ─────────────────────────────────────────────────────────
    const _Loc('L50', 'Lecture Hall'),
    const _Loc('N24', 'Lecture Hall'),
    // ── Others ───────────────────────────────────────────────────────────────
    const _Loc('PSZ Library', 'Perpustakaan Sultanah Zanariah'),
    const _Loc('MSI', 'Sultan Ismail Mosque'),
    const _Loc('V01', 'Health Center'),
    const _Loc('MA1', 'Arked Angkasa'),
    const _Loc('MA2', 'Arked Angkasa'),
  ];
}

final _utmLocations = _buildLocations();

// ─────────────────────────────────────────────────────────────
// Report Form — collects item details and runs matching algo
// ─────────────────────────────────────────────────────────────
class ReportFormPage extends StatefulWidget {
  final String reportType; // 'Lost' or 'Found'
  const ReportFormPage({super.key, required this.reportType});

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _colourCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  String _category = _categories[0];
  String? _selectedLocation; // replaces _locationCtrl
  bool _isLoading = false;
  File? _imageFile;

  @override
  void dispose() {
    _descCtrl.dispose();
    _colourCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  // ── Location picker ───────────────────────────────────────────────────────
  Future<void> _openLocationPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LocationSearchSheet(),
    );
    if (result != null) setState(() => _selectedLocation = result);
  }

  // ── Image picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadImage(String docId) async {
    if (_imageFile == null) return null;
    final ref = FirebaseStorage.instance.ref('report_images/$docId.jpg');
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  // ── String similarity: Dice coefficient on character bigrams ──────────────
  double _similarity(String a, String b) {
    a = a.toLowerCase().trim();
    b = b.toLowerCase().trim();
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;

    Set<String> bigrams(String s) {
      final set = <String>{};
      for (int i = 0; i < s.length - 1; i++) {
        set.add(s.substring(i, i + 2));
      }
      return set;
    }

    final bg1 = bigrams(a);
    final bg2 = bigrams(b);
    final overlap = bg1.intersection(bg2).length;
    return (2.0 * overlap) / (bg1.length + bg2.length);
  }

  // ── Matching algorithm ────────────────────────────────────────────────────
  Future<void> _runMatching(
    String newDocId,
    Map<String, dynamic> newReport,
  ) async {
    final db = FirebaseFirestore.instance;
    final oppositeType = widget.reportType == 'Lost' ? 'Found' : 'Lost';

    final existing = await db
        .collection('Reports')
        .where('type', isEqualTo: oppositeType)
        .get();

    for (final doc in existing.docs) {
      final other = doc.data();

      if (['sensitive', 'matched', 'resolved'].contains(other['status'])) {
        continue;
      }

      double score = 0.0;

      if ((other['category'] ?? '').toString().toLowerCase() ==
          (newReport['category'] ?? '').toString().toLowerCase()) {
        score += 0.30;
      }
      if ((other['colour'] ?? '').toString().toLowerCase() ==
          (newReport['colour'] ?? '').toString().toLowerCase()) {
        score += 0.25;
      }
      if ((other['brand'] ?? '').toString().toLowerCase() ==
          (newReport['brand'] ?? '').toString().toLowerCase()) {
        score += 0.15;
      }
      if (_similarity(
            other['description'] ?? '',
            newReport['description'] ?? '',
          ) >=
          0.70) {
        score += 0.30;
      }

      if (score >= 0.60) {
        final uid1 = newReport['uid'] as String;
        final uid2 = (other['uid'] ?? '') as String;
        final lostUid = widget.reportType == 'Lost' ? uid1 : uid2;
        final foundUid = widget.reportType == 'Lost' ? uid2 : uid1;

        final matchRef = await db.collection('Matches').add({
          'reportId1': newDocId,
          'reportId2': doc.id,
          'uid1': uid1,
          'uid2': uid2,
          'involvedUsers': [uid1, uid2],
          'score': score,
          'category': newReport['category'],
          'summary':
              '${widget.reportType} vs $oppositeType · ${newReport['category']}',
          'status': 'pending',
          'chatId': null,
          'qrToken': null,
          'timestamp': FieldValue.serverTimestamp(),
        });

        final chatRef = await db.collection('Chats').add({
          'matchId': matchRef.id,
          'participants': [lostUid, foundUid],
          'roles': {lostUid: 'owner', foundUid: 'finder'},
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'closed': false,
        });

        await matchRef.update({'chatId': chatRef.id});

        // Determine which report is Lost and which is Found for labelling
        final lostReport =
            widget.reportType == 'Lost' ? newReport : other;
        final foundReport =
            widget.reportType == 'Lost' ? other : newReport;

        await db
            .collection('Chats')
            .doc(chatRef.id)
            .collection('Messages')
            .add({
          'senderId': 'system',
          'type': 'match_details',
          'content': 'A potential match was found. Please verify the details below.',
          'matchScore': score,
          'lostReport': {
            'category': lostReport['category'] ?? '—',
            'colour': lostReport['colour'] ?? '—',
            'brand': lostReport['brand'] ?? '—',
            'location': lostReport['location'] ?? '—',
            'description': lostReport['description'] ?? '—',
          },
          'foundReport': {
            'category': foundReport['category'] ?? '—',
            'colour': foundReport['colour'] ?? '—',
            'brand': foundReport['brand'] ?? '—',
            'location': foundReport['location'] ?? '—',
            'description': foundReport['description'] ?? '—',
          },
          'timestamp': FieldValue.serverTimestamp(),
        });

        await db
            .collection('Reports')
            .doc(newDocId)
            .update({'status': 'matched'});
        await db
            .collection('Reports')
            .doc(doc.id)
            .update({'status': 'matched'});
      }
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance.collection('Reports').doc();
      final imageUrl = await _uploadImage(docRef.id);

      final newReport = <String, dynamic>{
        'uid': uid,
        'type': widget.reportType,
        'location': _selectedLocation ?? '',
        'category': _category,
        'description': _descCtrl.text.trim(),
        'colour': _colourCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      };

      await docRef.set(newReport);
      await _runMatching(docRef.id, newReport);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Report submitted! Checking for matches...')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLost = widget.reportType == 'Lost';
    final accentColor = isLost ? _maroon : Colors.green.shade700;
    final accentDark =
        isLost ? const Color(0xFF5C0000) : Colors.green.shade900;

    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.8),
      ),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // ── Gradient SliverAppBar ──────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentDark, accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: Text(
                'Report ${widget.reportType} Item',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ── Form body ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Type banner ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentDark.withValues(alpha: 0.12),
                            accentColor.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isLost
                                  ? Icons.search_off_rounded
                                  : Icons.inventory_2_outlined,
                              color: accentColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLost
                                    ? 'LOST ITEM REPORT'
                                    : 'FOUND ITEM REPORT',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isLost
                                    ? 'Fill in details to find your item'
                                    : 'Help someone find their item',
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Section: Where ───────────────────────────────────
                    _SectionHeader(
                      icon: Icons.location_on_outlined,
                      label: 'Where was it?',
                      color: accentColor,
                    ),
                    const SizedBox(height: 12),

                    // Location searchable picker
                    FormField<String>(
                      initialValue: _selectedLocation,
                      validator: (_) => _selectedLocation == null
                          ? 'Please select a location'
                          : null,
                      builder: (state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _openLocationPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: state.hasError
                                      ? Colors.red
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      color: accentColor, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedLocation ??
                                          'Tap to search location...',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _selectedLocation != null
                                            ? Colors.black87
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.search,
                                      color: Colors.grey.shade400, size: 20),
                                ],
                              ),
                            ),
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 6, left: 14),
                              child: Text(
                                state.errorText!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Section: Item Details ────────────────────────────
                    _SectionHeader(
                      icon: Icons.info_outline_rounded,
                      label: 'Item Details',
                      color: accentColor,
                    ),
                    const SizedBox(height: 12),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: fieldDecoration.copyWith(
                        labelText: 'Category *',
                        prefixIcon: Icon(Icons.category_outlined,
                            color: accentColor, size: 20),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _category = val!),
                    ),
                    const SizedBox(height: 14),

                    // Colour + Brand side-by-side
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _colourCtrl,
                            decoration: fieldDecoration.copyWith(
                              labelText: 'Colour *',
                              hintText: 'e.g. Black',
                              prefixIcon: Icon(Icons.color_lens_outlined,
                                  color: accentColor, size: 20),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _brandCtrl,
                            decoration: fieldDecoration.copyWith(
                              labelText: 'Brand *',
                              hintText: 'e.g. Apple',
                              prefixIcon: Icon(
                                  Icons.branding_watermark_outlined,
                                  color: accentColor,
                                  size: 20),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: fieldDecoration.copyWith(
                        labelText: 'Description *',
                        hintText:
                            'Describe the item in as much detail as possible...',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 56),
                          child: Icon(Icons.description_outlined,
                              color: accentColor, size: 20),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A detailed description improves the matching score.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Section: Photo ───────────────────────────────────
                    _SectionHeader(
                      icon: Icons.photo_camera_outlined,
                      label: 'Add a Photo',
                      color: accentColor,
                      subtitle: 'Optional — helps with identification',
                    ),
                    const SizedBox(height: 12),

                    // Image picker
                    GestureDetector(
                      onTap: _pickImage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _imageFile != null ? 200 : 130,
                        decoration: BoxDecoration(
                          color: _imageFile != null
                              ? Colors.black
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _imageFile != null
                                ? Colors.transparent
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _imageFile != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_imageFile!,
                                        fit: BoxFit.cover),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _imageFile = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close,
                                              color: Colors.white,
                                              size: 16),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit,
                                                color: Colors.white,
                                                size: 12),
                                            SizedBox(width: 4),
                                            Text('Change',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 30,
                                          color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Tap to add a photo',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'JPG / PNG from gallery',
                                      style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Submit button ────────────────────────────────────
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? null
                            : LinearGradient(
                                colors: [accentDark, accentColor],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: _isLoading ? Colors.grey.shade300 : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isLoading
                            ? []
                            : [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isLoading ? null : _submit,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLoading)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              else
                                const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _isLoading
                                    ? 'Submitting...'
                                    : 'Submit Report',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Section header with accent bar
// ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: subtitle != null ? 34 : 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Location search modal bottom sheet
// ─────────────────────────────────────────────────────────────
class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet();

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<_Loc> _filtered = _utmLocations;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _utmLocations
          : _utmLocations.where((l) => l.matches(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle bar ─────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ──────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: _maroon),
                SizedBox(width: 8),
                Text(
                  'Select Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Search field ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search location (e.g. N28, KTDI, Library...)',
                prefixIcon: const Icon(Icons.search, color: _maroon),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _maroon, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Result count ────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filtered.length} location${_filtered.length == 1 ? '' : 's'} found',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No locations match your search.',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(
                        left: 12, right: 12, bottom: 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (ctx, i) {
                      final loc = _filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              _maroon.withValues(alpha: 0.10),
                          child: Text(
                            loc.code.substring(0, 1),
                            style: const TextStyle(
                              color: _maroon,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          loc.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          loc.group,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                        onTap: () =>
                            Navigator.pop(ctx, loc.display),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
