import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../api/services/_dio_error.dart';
import '../api/services/auth_api.dart';
import '../api/services/user_hifz_api.dart';
import '../bloc/auth_cubit.dart';
import 'widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.apiClient});

  /// Shared app-wide client — reused (not re-created) so token refreshes don't
  /// invalidate the main client's session.
  final ApiClient apiClient;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _study;
  late TextEditingController _certificates;
  late TextEditingController _dob;
  late TextEditingController _currentPassword;
  late TextEditingController _newPassword;
  late TextEditingController _confirmPassword;
  bool _saving = false;
  bool _changingPassword = false;

  late final UserHifzApi _hifzApi;
  List<List<int>> _hifzRanges = const [];
  bool _loadingHifz = true;
  String? _hifzError;

  @override
  void initState() {
    super.initState();
    _hifzApi = UserHifzApi(widget.apiClient);
    _loadHifz();
    final user = context.read<AuthCubit>().state.user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phoneNumber ?? '');
    _study = TextEditingController(text: user?.study ?? '');
    _certificates = TextEditingController(text: user?.certificates ?? '');
    _dob = TextEditingController(text: user?.dateOfBirth ?? '');
    _currentPassword = TextEditingController();
    _newPassword = TextEditingController();
    _confirmPassword = TextEditingController();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _study.dispose();
    _certificates.dispose();
    _dob.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dob.text) ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final iso = picked.toIso8601String().substring(0, 10);
      setState(() => _dob.text = iso);
    }
  }

  String? _trimmed(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _loadHifz() async {
    setState(() {
      _loadingHifz = true;
      _hifzError = null;
    });
    try {
      final ranges = await _hifzApi.getRanges();
      if (!mounted) return;
      setState(() {
        _hifzRanges = ranges;
        _loadingHifz = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hifzError = e.message;
        _loadingHifz = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hifzError = e.toString();
        _loadingHifz = false;
      });
    }
  }

  Future<void> _addHifz() async {
    final input = await showDialog<_UserHifzInput>(
      context: context,
      builder: (_) => const _AddUserHifzDialog(),
    );
    if (input == null) return;
    try {
      await _hifzApi.create(
        fromJuz: input.fromJuz,
        toJuz: input.toJuz,
        date: input.date,
        label: input.label,
        notes: input.notes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة الحفظ')),
        );
      }
      await _loadHifz();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإضافة: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإضافة: $e')),
        );
      }
    }
  }

  String _rangeLabel(List<int> pair) {
    if (pair.isEmpty) return '';
    final from = pair.first;
    final to = pair.length > 1 ? pair.last : pair.first;
    return from == to ? 'الجزء $from' : 'الجزء $from - $to';
  }

  Widget _buildHifzSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'حفظي من القرآن',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loadingHifz ? null : _loadHifz,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingHifz)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_hifzError != null)
          Text(_hifzError!, style: const TextStyle(color: Colors.redAccent))
        else if (_hifzRanges.isEmpty)
          const Text('لا يوجد حفظ مسجّل', style: TextStyle(color: Colors.black54))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pair in _hifzRanges)
                Chip(label: Text(_rangeLabel(pair))),
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addHifz,
          icon: const Icon(Icons.add),
          label: const Text('إضافة حفظ'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthCubit>().updateProfile(
            firstName: _trimmed(_firstName),
            lastName: _trimmed(_lastName),
            email: _trimmed(_email),
            phoneNumber: _trimmed(_phone),
            study: _trimmed(_study),
            certificates: _trimmed(_certificates),
            dateOfBirth: _trimmed(_dob),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التعديلات')),
        );
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _changingPassword = true);
    try {
      await context.read<AuthCubit>().changePassword(
            _currentPassword.text,
            _newPassword.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
        );
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التغيير: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التغيير: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _showChangePasswordDialog() {
    _currentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: SingleChildScrollView(
            child: Form(
              key: _passwordFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      return s.isEmpty ? 'مطلوب' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'مطلوب';
                      if (s.length < 8) return 'يجب أن تكون 8 أحرف على الأقل';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'مطلوب';
                      if (s != _newPassword.text) {
                        return 'كلمات المرور غير متطابقة';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: _changingPassword ? null : _changePassword,
              child: _changingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تغيير'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthCubit, dynamic>((c) => c.state.user);
    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('الملف الشخصي')),
          drawer: const AppDrawer(),
          body: user == null
              ? const Center(child: Text('لا يوجد مستخدم'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ReadOnlyTile(
                          label: 'اسم المستخدم',
                          value: user.username as String,
                        ),
                        const SizedBox(height: 8),
                        _ReadOnlyTile(
                          label: 'اسم المسجد',
                          value: (user.mosqueName as String?) ?? '—',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _firstName,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الأول',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastName,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الأخير',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return null;
                            final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
                            return ok ? null : 'بريد إلكتروني غير صحيح';
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dob,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الميلاد',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _study,
                          decoration: const InputDecoration(
                            labelText: 'الدراسة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _certificates,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'الشهادات',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: const Text('حفظ التعديلات'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock),
                          label: const Text('تغيير كلمة المرور'),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildHifzSection(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReadOnlyTile extends StatelessWidget {
  const _ReadOnlyTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
      ),
    );
  }
}

/// Result returned by [_AddUserHifzDialog] on confirm.
class _UserHifzInput {
  const _UserHifzInput({
    required this.fromJuz,
    required this.toJuz,
    required this.date,
    required this.label,
    this.notes,
  });
  final int fromJuz;
  final int toJuz;
  final String date; // ISO datetime, e.g. 2026-07-01T12:00:00Z
  final String label;
  final String? notes;
}

class _AddUserHifzDialog extends StatefulWidget {
  const _AddUserHifzDialog();

  @override
  State<_AddUserHifzDialog> createState() => _AddUserHifzDialogState();
}

class _AddUserHifzDialogState extends State<_AddUserHifzDialog> {
  static const _labels = ['حفظ', 'مراجعة', 'تثبيت', 'حفظ سابق'];

  int _fromJuz = 1;
  int _toJuz = 1;
  String _label = 'حفظ';
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String _dateStr() =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (_fromJuz > _toJuz) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الجزء الأول يجب أن يكون قبل الأخير')),
      );
      return;
    }
    Navigator.pop(
      context,
      _UserHifzInput(
        fromJuz: _fromJuz,
        toJuz: _toJuz,
        date: '${_dateStr()}T12:00:00Z',
        label: _label,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة حفظ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'التاريخ',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_dateStr(), textDirection: TextDirection.ltr),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _fromJuz,
                      decoration: const InputDecoration(
                        labelText: 'من الجزء',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (int j = 1; j <= 30; j++)
                          DropdownMenuItem(value: j, child: Text('$j')),
                      ],
                      onChanged: (v) => setState(() => _fromJuz = v ?? _fromJuz),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _toJuz,
                      decoration: const InputDecoration(
                        labelText: 'إلى الجزء',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (int j = 1; j <= 30; j++)
                          DropdownMenuItem(value: j, child: Text('$j')),
                      ],
                      onChanged: (v) => setState(() => _toJuz = v ?? _toJuz),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'النوع',
                  border: OutlineInputBorder(),
                ),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final l in _labels)
                      ChoiceChip(
                        label: Text(l),
                        selected: _label == l,
                        onSelected: (_) => setState(() => _label = l),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(onPressed: _submit, child: const Text('إضافة')),
        ],
      ),
    );
  }
}
