import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Method helper để áp dụng style và dịch văn bản
Text trWithStyle(String key, {TextStyle? style}) {
  return Text(
    key.tr, // Dịch văn bản
    style: style, // Áp dụng style
  );
}
