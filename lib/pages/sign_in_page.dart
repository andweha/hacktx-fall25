// lib/pages/sign_in_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../main_navigation.dart';
import '../main.dart'; // Import bootstrapUserDocs

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> with TickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _signinUsernameCtrl = TextEditingController();
  final _signinPassCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  TabController? _tabController;
  TabController? _upgradeTabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _upgradeTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _upgradeTabController?.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _signinUsernameCtrl.dispose();
    _signinPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _mirrorPublicProfile(User u, {String? preferredName}) async {
    if (u.uid.isEmpty) {
      print('_mirrorPublicProfile: Error - User UID is empty');
      return;
    }
    
    final displayName =
        (preferredName?.trim().isNotEmpty == true ? preferredName!.trim() : (u.displayName ?? '')) ;
    await FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(u.uid)
        .set({
      'displayName': displayName,
      'username': displayName.isNotEmpty ? displayName : 'user-${u.uid.substring(0,4)}',
      'photoURL': u.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureProfile(User u, {String? preferredName}) async {
    if (u.uid.isEmpty) {
      print('_ensureProfile: Error - User UID is empty');
      return;
    }
    
    final ref =
        FirebaseFirestore.instance.collection('user_profiles').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final fallback =
          preferredName ?? u.displayName ?? 'user-${u.uid.substring(0, 4)}';
      await ref.set({
        'displayName': fallback,
        'username': fallback,
        'photoURL': u.photoURL,
        'anon': u.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'friendUids': [],
        'prefs': {},
      });
      await _mirrorPublicProfile(u, preferredName: fallback);
    } else {
      if (preferredName != null && preferredName.isNotEmpty) {
        await ref.set({'displayName': preferredName},
            SetOptions(merge: true));
        await _mirrorPublicProfile(u, preferredName: preferredName);
      } else {
        await _mirrorPublicProfile(u);
      }
    }
  }

  void _setErr(Object e) {
    setState(() => _error = e.toString());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: $_error')));
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;

    if (u != null) {
      // If you also want guests to skip this page, keep as-is.
      // If you only want permanent users to skip, change to: if (u != null && !u.isAnonymous)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      });
      return const SizedBox.shrink(); // Render nothing while redirecting
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                const SizedBox(height: 8),
                
                 // Header
                 Text(
                   u == null ? 'Sign in / Link account' : 
                   u.isAnonymous ? 'Create Permanent Account' : 
                   'Sign in / Link account',
                   style: const TextStyle(
                     fontSize: 28,
                     fontWeight: FontWeight.bold,
                     color: Color(0xFF2D3748),
                   ),
                 ),

                const SizedBox(height: 24),

          if (_error != null) ...[
                  Container(
        padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFED7D7).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE53E3E),
                        width: 1,
                      ),
                    ),
                    child: Row(
        children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFE53E3E),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFE53E3E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
          ],

          if (u == null) ...[
                  _buildWelcomeSection(),
                ] else if (u.isAnonymous) ...[
                  _buildUpgradeSection(),
                ] else ...[
                  _buildSignedInSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Guest section
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF8F9FA),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.waving_hand,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Quick Start',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Guest option - smaller button
                Center(
                  child: Container(
                    width: 240, // Increased width to accommodate content
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667EEA).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                         // Use Firebase Anonymous auth (simpler and more reliable)
                        print('Guest sign-in: Starting anonymous sign-in');
                        final user = await AuthService.instance.ensureAnon();
                        print('Guest sign-in: Anonymous user created: ${user.uid}');
                        
                        if (user.uid.isEmpty) {
                          throw Exception('Guest user ID is empty');
                        }
                         
                         // Bootstrap documents for the anonymous user
                         try {
                           await _ensureProfile(user);
                           print('Guest sign-in: Bootstrap completed');
                        } catch (bootstrapError) {
                          print('Guest sign-in: Bootstrap failed but continuing: $bootstrapError');
                          // Don't fail the entire sign-in process if bootstrap fails
                        }
                         
                         // Navigate directly to main navigation
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MainNavigation()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        print('Guest sign-in: Error occurred: $e');
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Continue as guest',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_busy) ...[
                            const SizedBox(width: 6),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Create Permanent Account option
                Center(
                  child: Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() {
                                _busy = true;
                                _error = null;
                              });
                              try {
                                // Use Firebase Anonymous auth first
                                print('Create Permanent Account: Starting anonymous sign-in');
                                final user = await AuthService.instance.ensureAnon();
                                print('Create Permanent Account: Anonymous user created: ${user.uid}');
                                
                                if (user.uid.isEmpty) {
                                  throw Exception('Guest user ID is empty');
                                }
                                
                                 // Bootstrap documents for the anonymous user
                                 try {
                                   await _ensureProfile(user);
                                   print('Create Permanent Account: Bootstrap completed');
                                } catch (bootstrapError) {
                                  print('Create Permanent Account: Bootstrap failed but continuing: $bootstrapError');
                                  // Don't fail the entire sign-in process if bootstrap fails
                                }
                                
                                // Wait a moment for auth state to update, then navigate to upgrade page
                                await Future.delayed(const Duration(milliseconds: 100));
                                
                                // Navigate to the upgrade page (same as Settings -> Create Permanent Account)
                                // The auth state change will automatically show the upgrade section
                                if (mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const SignInPage()),
                                  );
                                }
                              } catch (e) {
                                print('Create Permanent Account: Error occurred: $e');
                                _setErr(e);
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_circle_outlined,
                            color: Color(0xFF667EEA),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Create Permanent Account',
                            style: TextStyle(
                              color: Color(0xFF667EEA),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_busy) ...[
                            const SizedBox(width: 6),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Tabbed authentication section
        Container(
          constraints: const BoxConstraints(minHeight: 400),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF8F9FA),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: TabBar(
                  controller: _tabController!,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF718096),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.login, size: 18),
                      text: 'Google',
                    ),
                    Tab(
                      icon: Icon(Icons.person, size: 18),
                      text: 'Username',
                    ),
                  ],
                ),
              ),
              
              // Tab content
              SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabController!,
                  children: [
                    _buildGoogleTab(),
                    _buildUsernameTab(),
                  ],
                ),
              ),
            ],
          ),
        ),


      ],
    );
  }

  Widget _buildGoogleTab() {
    if (!kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Google sign-in is only available on web',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Continue with Google',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in or create account using your Google account',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF34A853)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4285F4).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final provider = GoogleAuthProvider()
                          ..setCustomParameters({'prompt': 'select_account'});
                        final cred = await FirebaseAuth.instance
                            .signInWithPopup(provider);
                        
                         if (cred.user?.uid.isEmpty ?? true) {
                           throw Exception('Google sign-in failed - no user ID');
                         }
                         
                         await _ensureProfile(cred.user!);
                         
                         // Navigate directly to main navigation after Google sign-in
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MainNavigation()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.login,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Sign in with Username',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create an account or sign in with your username and password',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Username field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _signinUsernameCtrl,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: Color(0xFF667EEA),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Password field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _signinPassCtrl,
              obscureText: true,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: Color(0xFF667EEA),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38A169), Color(0xFF2F855A)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38A169).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final cred = await AuthService.instance
                            .signInUsernamePassword(
                                _signinUsernameCtrl.text.trim(),
                                _signinPassCtrl.text);
                        
                         if (cred.user?.uid.isEmpty ?? true) {
                           throw Exception('Username sign-in failed - no user ID');
                         }
                         
                         await _ensureProfile(cred.user!);
                         
                         // Navigate directly to main navigation after sign-in
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MainNavigation()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign in',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF8F9FA),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFED8936), Color(0xFFDD6B20)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.upgrade,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Upgrade your guest account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF718096),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: TabBar(
                  controller: _upgradeTabController!,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF718096),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.login, size: 18),
                      text: 'Google',
                    ),
                    Tab(
                      icon: Icon(Icons.person, size: 18),
                      text: 'Username',
                    ),
                  ],
                ),
              ),
              
              // Tab content
              SizedBox(
                height: 340,
                child: TabBarView(
                  controller: _upgradeTabController!,
                  children: [
                    _buildUpgradeGoogleTab(),
                    _buildUpgradeUsernameTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeGoogleTab() {
    if (!kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Google sign-in is only available on web',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Link Google Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Link your Google account to keep your data',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final provider = GoogleAuthProvider()
                          ..setCustomParameters({'prompt': 'select_account'});
                        await FirebaseAuth.instance.currentUser!
                            .linkWithPopup(provider);

                         final user = FirebaseAuth.instance.currentUser!;
                         await _ensureProfile(user);
                         
                         if (user.uid.isEmpty) {
                           throw Exception('User ID is empty after linking Google');
                         }
                         
                         // Auth state change will automatically redirect to MainNavigation
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.login,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Link Google (keep my data)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeUsernameTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Create Username Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a permanent account with username and password',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Username field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _usernameCtrl,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: Color(0xFF667EEA),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Password field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: Color(0xFF667EEA),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Create account button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await AuthService.instance.linkUsernamePassword(
                            _usernameCtrl.text.trim(), _passCtrl.text);
                        final user = FirebaseAuth.instance.currentUser!;
                        if (user.uid.isEmpty) {
                          throw Exception('User ID is empty after linking account');
                        }
                        await _ensureProfile(user,
                            preferredName: _nameCtrl.text.trim());
                        await FirebaseFirestore.instance
                            .collection('user_profiles')
                            .doc(user.uid)
                            .set({'anon': false}, SetOptions(merge: true));
                        
                        // Auth state change will automatically redirect to MainNavigation
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(
                Icons.link,
                color: Color(0xFF667EEA),
                size: 20,
              ),
              label: const Text(
                'Create account (keep my data)',
                style: TextStyle(
                  color: Color(0xFF667EEA),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInSection() {
    final u = FirebaseAuth.instance.currentUser!;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF8F9FA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38A169), Color(0xFF2F855A)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'You are signed in',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFC6F6D5).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFC6F6D5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UID: ${u.uid.substring(0, 8)}...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Providers: ${u.providerData.map((p) => p.providerId).join(", ")}',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53E3E), Color(0xFFC53030)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53E3E).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await AuthService.instance.signOut();
                        // The auth state change will automatically redirect to SignInPage
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
