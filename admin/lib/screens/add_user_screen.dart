import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _millNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New User'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'User Configuration',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField('Full Name', _nameController, Icons.person),
                const SizedBox(height: 15),
                _buildTextField(
                  'Email Address',
                  _emailController,
                  Icons.email,
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  'Primary Phone',
                  _phoneController,
                  Icons.phone,
                  type: TextInputType.phone,
                  isRequired: false,
                ),
                const SizedBox(height: 30),

                const Text(
                  'Device Assignment',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  'Device ID (e.g., SS_DEV_001)',
                  _deviceIdController,
                  Icons.developer_board,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  'Rice Mill Name (e.g., Radha Krishna)',
                  _millNameController,
                  Icons.factory_outlined,
                  isRequired: false,
                ),
                const SizedBox(height: 15),
                const SizedBox(height: 40),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saving user...')),
                        );

                        try {
                          final response = await http.post(
                            Uri.parse(
                              '${ApiService.baseUrl}/api/users/register',
                            ),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'name': _nameController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'email': _emailController.text.trim().toLowerCase(),
                              'deviceId': _deviceIdController.text.trim(),
                              'millName': _millNameController.text.trim(),
                            }),
                          );

                          if (response.statusCode == 201) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'User registered successfully!',
                                  ),
                                ),
                              );
                              Navigator.pop(
                                context,
                                true,
                              ); // Return true to refresh list
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: ${response.body}'),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'REGISTER USER',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),  
    );
  }
 
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: isRequired ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal.withValues(alpha: 0.54)),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
