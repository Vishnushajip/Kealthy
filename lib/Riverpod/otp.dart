import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart'as http;
import '../LandingPage/HomePage.dart';

class OtpState {
  final String? otp;
  final bool isLoading;
  final String? error;

  OtpState({
    this.otp,
    this.isLoading = false,
    this.error,
  });
}

class OtpNotifier extends StateNotifier<OtpState> {
  OtpNotifier() : super(OtpState());

  void setOtp(String otp) {
    state = OtpState(otp: otp);
  }

  Future<void> verifyOtp(String verificationId, String otp, BuildContext context, {Function? onSuccess}) async {
    state = OtpState(isLoading: true);
    const url = 'https://us-central1-kealthy-90c55.cloudfunctions.net/api/verify-otp';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'verificationId': verificationId,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        state = OtpState();
        if (onSuccess != null) {
          onSuccess();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage()),
        );
      } else {
        state = OtpState(error: 'OTP verification failed');
      }
    } catch (e) {
      state = OtpState(error: 'An error occurred');
    }
  }

  Future<void> resendOtp(String phoneNumber) async {
    const url = ' ';
    state = OtpState(isLoading: true);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      if (response.statusCode == 200) {
        state = OtpState();
      } else {
        state = OtpState(error: 'Failed to resend OTP');
      }
    } catch (e) {
      state = OtpState(error: 'An error occurred while resending OTP');
    }
  }
}

final otpProvider = StateNotifierProvider<OtpNotifier, OtpState>(
  (ref) => OtpNotifier(),
);


