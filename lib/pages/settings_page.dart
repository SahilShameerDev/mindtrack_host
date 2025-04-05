import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindtrack/services/theme_service.dart';

class SettingsPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const SettingsPage({
    Key? key,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  bool _isDarkMode = false;
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animController.forward();
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadThemeSettings() async {
    final isDark = await ThemeService.isDarkMode();
    setState(() {
      _isDarkMode = isDark;
    });
  }

  Future<void> _toggleTheme() async {
    HapticFeedback.mediumImpact();
    
    final ThemeMode newMode = await ThemeService.toggleThemeMode();
    setState(() {
      _isDarkMode = newMode == ThemeMode.dark;
    });
    
    widget.onThemeChanged(newMode);
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors that adapt to current theme mode
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _animation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: _isDarkMode 
                      ? Color(0xFF2C2C2C) 
                      : Color.fromARGB(168, 254, 140, 0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette,
                      size: 24,
                      color: primaryColor,
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              _buildThemeToggleCard(
                primaryColor: primaryColor, 
                secondaryColor: secondaryColor,
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
              SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleCard({
    required Color primaryColor,
    required Color secondaryColor,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _isDarkMode 
          ? Color(0xFF2C2C2C) 
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _isDarkMode 
                          ? 'Switch to light theme' 
                          : 'Switch to dark theme',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isDarkMode,
                  onChanged: (_) => _toggleTheme(),
                  activeColor: primaryColor,
                  activeTrackColor: primaryColor.withOpacity(0.5),
                ),
              ],
            ),
            SizedBox(height: 40),
            _buildThemeModePreview(
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModePreview({
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: _isDarkMode ? Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // App bar preview
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.arrow_back, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text(
                  'Preview',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          
          // Content preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text preview
                  Text(
                    'Theme Preview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This is how your app will look',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Button preview
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Button',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Button',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  
                  // Card preview
                  SizedBox(height: 26),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Color(0xFF2C2C2C) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: primaryColor,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Card Preview',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
