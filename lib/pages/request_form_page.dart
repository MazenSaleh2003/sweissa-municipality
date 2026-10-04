import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../core/models.dart';
import '../core/widgets.dart';

class RequestFormPage extends StatefulWidget {
  const RequestFormPage({super.key, this.service = false});
  final bool service;
  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController(),
      _location = TextEditingController(),
      _phone = TextEditingController();
  RequestDraft? _draft;
  bool _busy = false, _locating = false, _saved = false;
  int _revision = 0;
  Timer? _debounce;
  List<String> get _categories =>
      widget.service ? serviceCategories : issueCategories;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draft != null) return;
    final scope = AppScope.of(context), owner = scope.repository.userId;
    if (owner == null) return;
    _draft =
        scope.drafts.read(owner, widget.service) ??
        RequestDraft(
          id: const Uuid().v4(),
          ownerId: owner,
          service: widget.service,
        );
    if (!_categories.contains(_draft!.category)) {
      _draft!.category = _categories.first;
    }
    _description.text = _draft!.description;
    _location.text = _draft!.location;
    _phone.text = _draft!.phone;
    _saved = scope.drafts.read(owner, widget.service) != null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _description.dispose();
    _location.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _capture() {
    final d = _draft!;
    d.description = _description.text;
    d.location = _location.text;
    d.phone = _phone.text;
  }

  void _changed() {
    _revision++;
    _capture();
    setState(() => _saved = false);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _save());
  }

  Future<bool> _save() async {
    if (_draft == null) return false;
    _capture();
    final revision = _revision;
    try {
      await AppScope.of(context).drafts.save(_draft!);
      if (mounted && revision == _revision) setState(() => _saved = true);
      return true;
    } catch (_) {
      if (mounted) {
        message(
          context,
          'لم تُحفظ المسودة على الجهاز. أبقِ هذه الصفحة مفتوحة وحاول مجدداً.',
        );
      }
      return false;
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    _debounce?.cancel();
    _capture();
    setState(() => _busy = true);
    final scope = AppScope.of(context);
    await _save();
    try {
      await scope.repository.submit(_draft!);
      // Database acknowledgement is the only source of submission success.
      var cleared = true;
      try {
        await scope.drafts.clear(_draft!.ownerId, widget.service);
      } catch (_) {
        cleared = false;
      }
      if (!mounted) return;
      message(
        context,
        cleared
            ? 'تم استلام الطلب رقم ${shortId(_draft!.id)}. يمكنك متابعته في طلباتي.'
            : 'تم استلام الطلب. تعذر حذف المسودة المحلية؛ إعادة الإرسال لا تنشئ طلباً مكرراً.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photo(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = detectPhotoExtension(bytes);
      if (!mounted) return;
      if (bytes.length > 1536 * 1024 || extension == null) {
        message(
          context,
          'اختر صورة JPG أو PNG أو WebP لا تتجاوز 1.5 MB ليُحفظ الطلب على جهازك.',
        );
        return;
      }
      setState(() {
        _draft!.photo = bytes;
        _draft!.photoExtension = extension;
      });
      _changed();
    } catch (error) {
      if (mounted) {
        message(
          context,
          'تعذر اختيار الصورة. تحقق من صلاحية الكاميرا أو اختر صورة من الجهاز.',
        );
      }
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Location disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Permission denied');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (mounted) {
        setState(() {
          _draft!.latitude = position.latitude;
          _draft!.longitude = position.longitude;
        });
        _changed();
      }
    } catch (_) {
      if (mounted) {
        message(
          context,
          'تعذر تحديد موقعك. يمكنك كتابة العنوان بدلاً منه، أو تفعيل الموقع والصلاحية.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_draft == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState('سجّل الدخول قبل تقديم طلب.'),
      );
    }
    return PopScope(
      canPop: _busy ? false : _saved,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) return;
        final nav = Navigator.of(context);
        if (await _save() && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.service ? 'طلب خدمة' : 'الإبلاغ عن مشكلة'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'اكتب التفاصيل بوضوح. هذه الخدمة ليست قناة للاستجابة للطوارئ.',
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _draft!.category,
                      decoration: const InputDecoration(labelText: 'الفئة'),
                      items: _categories
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) {
                              _draft!.category = v!;
                              _changed();
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'وصف الطلب'),
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 4000,
                      onChanged: (_) => _changed(),
                      validator: (v) => (v?.trim().length ?? 0) < 10
                          ? 'اكتب وصفاً من 10 أحرف على الأقل.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _location,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'العنوان أو أقرب معلم',
                      ),
                      maxLength: 500,
                      onChanged: (_) => _changed(),
                      validator: (v) =>
                          !widget.service &&
                              (v?.trim().isEmpty ?? true) &&
                              _draft!.latitude == null
                          ? 'اكتب العنوان أو أضف موقعك.'
                          : null,
                    ),
                    TextFormField(
                      controller: _phone,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'هاتف للتواصل (اختياري)',
                      ),
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      maxLength: 40,
                      onChanged: (_) => _changed(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy || _locating ? null : _locate,
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        _locating
                            ? 'تحديد الموقع…'
                            : 'إضافة موقعي الحالي (اختياري)',
                      ),
                    ),
                    if (_draft!.latitude != null)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${_draft!.latitude!.toStringAsFixed(5)}, ${_draft!.longitude!.toStringAsFixed(5)}',
                            textDirection: TextDirection.ltr,
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _draft!.latitude = null;
                                      _draft!.longitude = null;
                                    });
                                    _changed();
                                  },
                            child: const Text('إزالة الموقع'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _photo(ImageSource.gallery),
                          icon: const Icon(Icons.photo_outlined),
                          label: const Text('إضافة صورة'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _photo(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('الكاميرا'),
                        ),
                      ],
                    ),
                    if (_draft!.photo != null) ...[
                      const SizedBox(height: 12),
                      Image.memory(
                        _draft!.photo!,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _draft!.photo = null;
                                  _draft!.photoExtension = null;
                                });
                                _changed();
                              },
                        child: const Text('إزالة الصورة'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _saved
                          ? 'حُفظت المسودة على هذا الجهاز. لم تُرسل بعد.'
                          : 'لم تُحفظ التغييرات بعد.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || _locating ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_busy ? 'جارٍ إرسال الطلب…' : 'إرسال الطلب'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _save(),
                      child: const Text('حفظ المسودة'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (!await confirm(
                                context,
                                'حذف المسودة من هذا الجهاز؟',
                              )) {
                                return;
                              }
                              if (!context.mounted) return;
                              try {
                                _debounce?.cancel();
                                await AppScope.of(
                                  context,
                                ).drafts.clear(_draft!.ownerId, widget.service);
                                if (context.mounted) Navigator.pop(context);
                              } catch (error) {
                                if (context.mounted) showError(context, error);
                              }
                            },
                      child: const Text('حذف المسودة'),
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
