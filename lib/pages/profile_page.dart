import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Add this import for haptic feedback
import 'package:hive_flutter/hive_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _professionController;
  String _selectedGender = 'Male';
  String _selectedStressLevel = 'Low';

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _stressLevels = ['Low', 'Moderate', 'High'];

  late AnimationController _fadeController;
  late AnimationController _buttonController;
  List<AnimationController> _fieldControllers = [];
  List<Animation<Offset>> _slideAnimations = [];

  @override
  void initState() {
    super.initState();
    
    // Setup animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _buttonController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    
    // Create field animations with staggered delays
    for (int i = 0; i < 5; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500),
      );
      _fieldControllers.add(controller);
      
      _slideAnimations.add(
        Tween<Offset>(
          begin: Offset(0.2, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        )),
      );
      
      // Stagger the animations
      Future.delayed(Duration(milliseconds: 100 * i), () {
        controller.forward();
      });
    }
    
    _fadeController.forward();
    
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userBox = await Hive.openBox('user_data');
    _nameController = TextEditingController(text: userBox.get('name'));
    _ageController = TextEditingController(text: userBox.get('age').toString());
    _professionController = TextEditingController(text: userBox.get('profession'));
    setState(() {
      _selectedGender = userBox.get('gender');
      _selectedStressLevel = userBox.get('stressLevel');
    });
  }

  Future<void> _updateUserData() async {
    final userBox = await Hive.openBox('user_data');
    await userBox.put('name', _nameController.text);
    await userBox.put('age', int.parse(_ageController.text));
    await userBox.put('profession', _professionController.text);
    await userBox.put('gender', _selectedGender);
    await userBox.put('stressLevel', _selectedStressLevel);

    if (mounted) {
      // Animate success notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              AnimatedBuilder(
                animation: AlwaysStoppedAnimation(0),
                builder: (context, child) {
                  return Icon(Icons.check_circle, color: Colors.white);
                },
              ),
              SizedBox(width: 10),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: Color(0xC4FF4000),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          animation: CurvedAnimation(
            parent: kAlwaysCompleteAnimation,
            curve: Curves.easeInOut,
          ),
        ),
      );
      
      // Add a delay before popping to show the animation
      Future.delayed(Duration(milliseconds: 1500), () {
        Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _buttonController.dispose();
    for (var controller in _fieldControllers) {
      controller.dispose();
    }
    _nameController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _animatedFormField(
                  index: 0,
                  child: _buildTextField(
                    controller: _nameController,
                    label: 'Name',
                    validator: (value) => 
                      value?.isEmpty ?? true ? 'Please enter your name' : null,
                  ),
                ),
                SizedBox(height: 20),
                _animatedFormField(
                  index: 1,
                  child: _buildTextField(
                    controller: _ageController,
                    label: 'Age',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter your age';
                      if (int.tryParse(value!) == null) return 'Please enter a valid age';
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),
                _animatedFormField(
                  index: 2,
                  child: _buildTextField(
                    controller: _professionController,
                    label: 'Profession',
                    validator: (value) => 
                      value?.isEmpty ?? true ? 'Please enter your profession' : null,
                  ),
                ),
                SizedBox(height: 20),
                _animatedFormField(
                  index: 3,
                  child: _buildDropdown(
                    label: 'Gender',
                    value: _selectedGender,
                    items: _genders,
                    onChanged: (value) => setState(() => _selectedGender = value!),
                  ),
                ),
                SizedBox(height: 20),
                _animatedFormField(
                  index: 4,
                  child: _buildDropdown(
                    label: 'Current Stress Level',
                    value: _selectedStressLevel,
                    items: _stressLevels,
                    onChanged: (value) => setState(() => _selectedStressLevel = value!),
                  ),
                ),
                SizedBox(height: 40),
                _animatedSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Same _buildTextField and _buildDropdown methods as RegisterPage
  // but with theme-based colors instead of hardcoded ones
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300),
      builder: (context, value, child) {
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Color.lerp(Colors.grey, primaryColor, value),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: primaryColor,
                width: 2.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.grey,
                width: 1.0,
              ),
            ),
          ),
          onTap: () {
            // Add small shake animation
            HapticFeedback.selectionClick();
          },
          onChanged: (_) {
            setState(() {}); // Trigger rebuild for animations
          },
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
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
            ),
          ),
        ),
      ],
    );
  }

  // Add this method to your class
  Widget _animatedFormField({
    required int index, 
    required Widget child
  }) {
    return FadeTransition(
      opacity: _fieldControllers[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: child,
      ),
    );
  }

  Widget _animatedSaveButton() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return MouseRegion(
      onEnter: (_) => _buttonController.forward(),
      onExit: (_) => _buttonController.reverse(),
      child: AnimatedBuilder(
        animation: _buttonController,
        builder: (context, child) {
          final scale = 1.0 + (0.05 * _buttonController.value);
          final brightness = 1.0 + (0.2 * _buttonController.value);
          
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    _animateSaveSuccess();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor.withOpacity(brightness),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4 + (2 * _buttonController.value),
                ),
                child: Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16 + (2 * _buttonController.value),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _animateSaveSuccess() async {
    // Create ripple effect
    final scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    await scaleController.forward();
    await _updateUserData();
    scaleController.dispose();
  }
}
