import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/entities.dart';

class Avatar extends StatelessWidget {
  const Avatar(this.u, {super.key, this.size = 46});
  final User u;
  final double size;
  @override
  Widget build(BuildContext c) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xffdbe8ff),
      backgroundImage: _image(u.avatar),
      child: _image(u.avatar) != null
          ? null
          : Text(
              u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: size * .4,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  ImageProvider? _image(String avatar) {
    if (avatar.isEmpty) return null;
    if (avatar.startsWith('base64:')) {
      try { return MemoryImage(base64Decode(avatar.substring(7))); } catch (_) { return null; }
    }
    return File(avatar).existsSync() ? FileImage(File(avatar)) : null;
  }
}
