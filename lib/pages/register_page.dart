import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mindtrack/pages/home_pages.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _professionController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedStressLevel = 'Low';

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _stressLevels = ['Low', 'Moderate', 'High'];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _saveUserData() async {
    final userBox = await Hive.openBox('user_data');
    await userBox.put('isRegistered', true);
    await userBox.put('name', _nameController.text);
    await userBox.put('age', int.parse(_ageController.text));
    await userBox.put('profession', _professionController.text);
    await userBox.put('gender', _selectedGender);
    await userBox.put('stressLevel', _selectedStressLevel);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Colors.white; // Keep text color white for better contrast

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40),
                Text(
                  'Welcome to MindTrack',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Please tell us about yourself',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 40),
                _buildTextField(
                  controller: _nameController,
                  label: 'Name',
                  validator: (value) => 
                    value?.isEmpty ?? true ? 'Please enter your name' : null,
                ),
                SizedBox(height: 20),
                _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter your age';
                    if (int.tryParse(value!) == null) return 'Please enter a valid age';
                    return null;
                  },
                ),
                SizedBox(height: 20),
                _buildTextField(
                  controller: _professionController,
                  label: 'Profession',
                  validator: (value) => 
                    value?.isEmpty ?? true ? 'Please enter your profession' : null,
                ),
                SizedBox(height: 20),
                _buildDropdown(
                  label: 'Gender',
                  value: _selectedGender,
                  items: _genders,
                  onChanged: (value) => setState(() => _selectedGender = value!),
                ),
                SizedBox(height: 20),
                _buildDropdown(
                  label: 'Current Stress Level',
                  value: _selectedStressLevel,
                  items: _stressLevels,
                  onChanged: (value) => setState(() => _selectedStressLevel = value!),
                ),
                SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _saveUserData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white70),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: primaryColor,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
