enum SabrMainType {
  awqaf('سبر الأوقاف'),
  mahad('سبر المعهد'),
  mahadTarakumi('سبر المعهد التراكمي'),
  hadith('سبر الحديث');

  const SabrMainType(this.label);
  final String label;
}

enum HadithType {
  arbaeen('الأربعين النووية');

  const HadithType(this.label);
  final String label;
}
