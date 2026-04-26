import 'package:flutter/material.dart';

/// Mapa de nombre → IconData para los iconos personalizables de cuentas.
const Map<String, IconData> kAccountIcons = {
  'account_circle': Icons.account_circle_outlined,
  'mail': Icons.mail_outline,
  'smartphone': Icons.smartphone_outlined,
  'work': Icons.work_outline,
  'school': Icons.school_outlined,
  'code': Icons.code,
  'shopping_cart': Icons.shopping_cart_outlined,
  'sports_esports': Icons.sports_esports_outlined,
  'music_note': Icons.music_note_outlined,
  'movie': Icons.movie_outlined,
  'cloud': Icons.cloud_outlined,
  'security': Icons.security_outlined,
  'business': Icons.business_outlined,
  'store': Icons.store_outlined,
  'photo_camera': Icons.photo_camera_outlined,
  'favorite': Icons.favorite_outline,
  'star': Icons.star_outline,
  'local_cafe': Icons.local_cafe_outlined,
  'directions_car': Icons.directions_car_outlined,
  'home': Icons.home_outlined,
  'flight': Icons.flight_outlined,
  'fitness_center': Icons.fitness_center_outlined,
  'medical_services': Icons.medical_services_outlined,
  'attach_money': Icons.attach_money,
  'credit_card': Icons.credit_card_outlined,
  'headset_mic': Icons.headset_mic_outlined,
  'alternate_email': Icons.alternate_email,
  'facebook': Icons.facebook,
  'language': Icons.language_outlined,
  'lock': Icons.lock_outline,
};

IconData iconFromName(String name) =>
    kAccountIcons[name] ?? Icons.account_circle_outlined;
