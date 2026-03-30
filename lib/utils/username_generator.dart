import 'dart:math';

class UsernameGenerator {
  static final _rand = Random();

  static String generateUsername(String fullName) {
    // "Ali Veli Yılmaz" → "aliveli"
    final parts = fullName
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .split(RegExp(r'\s+'));

    if (parts.isEmpty) return 'ogrenci${_rand.nextInt(9999)}';

    String base = parts.length == 1
        ? parts[0]
        : '${parts[0]}${parts[1]}';

    // Append 4-digit random suffix to avoid collisions
    final suffix = (_rand.nextInt(9000) + 1000).toString();
    return '${base.replaceAll(RegExp(r'[^a-z]'), '')}$suffix';
  }

  static String generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    return List.generate(8, (_) => chars[_rand.nextInt(chars.length)]).join();
  }
}
