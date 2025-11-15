import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../color/colors.dart';
import '../services/auth_service.dart';
import '../utils/page_transitions.dart';
import 'otp_verification_page.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCountryCode = '+63'; // Default to Philippines

  // Common country codes
  final List<Map<String, String>> _countryCodes = [
    {'code': '+63', 'country': 'Philippines'},
    {'code': '+1', 'country': 'US/CA'},
    {'code': '+44', 'country': 'UK'},
    {'code': '+91', 'country': 'India'},
    {'code': '+86', 'country': 'China'},
    {'code': '+81', 'country': 'Japan'},
    {'code': '+49', 'country': 'Germany'},
    {'code': '+33', 'country': 'France'},
    {'code': '+61', 'country': 'Australia'},
    {'code': '+971', 'country': 'UAE'},
    {'code': '+966', 'country': 'Saudi'},
    {'code': '+65', 'country': 'Singapore'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return '$_selectedCountryCode$cleaned';
  }

  bool _validatePhoneNumber(String phone) {
    // Basic validation: check if it has at least 10 digits
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return cleaned.length >= 10;
  }

  Future<void> _sendOTP() async {
    setState(() {
      _errorMessage = null;
    });

    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    if (!_validatePhoneNumber(phoneNumber)) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number (min 10 digits)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final fullPhoneNumber = _formatPhoneNumber(phoneNumber);

    await _authService.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Navigate to OTP verification page
          Navigator.push(
            context,
            SlidePageRoute(
              page: OTPVerificationPage(
                verificationId: verificationId,
                phoneNumber: fullPhoneNumber,
              ),
              direction: AxisDirection.right,
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = error;
          });
        }
      },
      onAutoVerified: (userCredential) {
        // Auto-verification successful (Android only)
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),

              const SizedBox(height: 20),

              // Header
              const Text(
                'Phone Sign In',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Enter your phone number to receive a verification code',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9CA3AF),
                ),
              ),

              const SizedBox(height: 40),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              // Phone number label
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              // Phone number input with country code selector
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage != null
                        ? Colors.red
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    // Country code dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          dropdownColor: const Color(0xFF1A2332),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF6B7280),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          items: _countryCodes.map((country) {
                            return DropdownMenuItem<String>(
                              value: country['code'],
                              child: Text(
                                '${country['code']} ${country['country']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCountryCode = value;
                                _errorMessage = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFF374151),
                    ),

                    // Phone number input
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(15),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Phone Number',
                          hintStyle: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (_) {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Info text
              const Text(
                'We\'ll send you a verification code via SMS. Standard message rates may apply.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 32),

              // Send Code Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _sendOTP,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'SEND CODE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Note about free tier
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Firebase offers 10,000 free phone verifications per month in the Blaze plan.',
                        style: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
