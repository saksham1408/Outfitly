import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../network/supabase_client.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/onboarding/style_quiz_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/catalog/presentation/subcategory_plp/subcategory_screen.dart';
import '../../features/catalog/product_detail_screen.dart';
import '../../features/design_studio/presentation/custom_embroidery_request_screen.dart';
import '../../features/design_studio/presentation/design_studio_screen.dart';
import '../../features/checkout/models/order_payload.dart';
import '../../features/measurements/presentation/measurement_decision_screen.dart';
import '../../features/measurements/presentation/manual_measurement_screen.dart';
import '../../features/measurements/presentation/book_tailor_screen.dart';
import '../../features/checkout/cart_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/order_success_screen.dart';
import '../../features/tracking/screens/order_tracking_screen.dart';
// Lookbook tab replaced by Outfitly AI — imports removed.
// import '../../features/lookbook/screens/lookbook_screen.dart';
// import '../../features/lookbook/screens/lookbook_detail_screen.dart';
import '../../features/outfitly_ai/presentation/outfitly_ai_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/search/screens/search_screen.dart';

/// Central route configuration for the app.
abstract final class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  /// Routes that don't require authentication.
  static const _publicRoutes = {
    '/login',
    '/register',
    '/otp-login',
    '/forgot-password',
  };

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final session = AppSupabase.client.auth.currentSession;
      final loggedIn = session != null;
      final path = state.matchedLocation;

      if (!loggedIn && !_publicRoutes.contains(path)) return '/login';
      if (loggedIn && _publicRoutes.contains(path)) return '/home';

      return null;
    },
    routes: [
      // ── Auth ──
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp-login',
        name: 'otpLogin',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ── Onboarding ──
      GoRoute(
        path: '/style-quiz',
        name: 'styleQuiz',
        builder: (context, state) => const StyleQuizScreen(),
      ),

      // ── Home (with bottom nav shell) ──
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(canPop: true),
      ),
      GoRoute(
        path: '/catalog',
        name: 'catalog',
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: '/subcategory/:id',
        name: 'subcategory',
        builder: (context, state) => SubcategoryScreen(
          subcategoryId: state.pathParameters['id']!,
          subcategoryName: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: '/product/:id',
        name: 'productDetail',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
        ),
        routes: [
          GoRoute(
            path: 'design-studio',
            name: 'designStudio',
            builder: (context, state) => DesignStudioScreen(
              productId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // ── Custom Embroidery Request (bespoke) ──
      GoRoute(
        path: '/embroidery/custom-request',
        name: 'customEmbroideryRequest',
        builder: (context, state) => const CustomEmbroideryRequestScreen(),
      ),

      // ── Measurements ──
      GoRoute(
        path: '/measurements/decision',
        name: 'measurementDecision',
        builder: (context, state) => MeasurementDecisionScreen(
          payload: state.extra as OrderPayload?,
        ),
      ),
      GoRoute(
        path: '/measurements/manual',
        name: 'manualMeasurement',
        builder: (context, state) => ManualMeasurementScreen(
          payload: state.extra as OrderPayload?,
        ),
      ),
      GoRoute(
        path: '/measurements/book-tailor',
        name: 'bookTailor',
        builder: (context, state) => BookTailorScreen(
          payload: state.extra as OrderPayload?,
        ),
      ),

      // ── Outfitly AI (replaces Lookbook tab) ──
      GoRoute(
        path: '/outfitly-ai',
        name: 'outfitlyAi',
        builder: (context, state) => const OutfitlyAiScreen(),
      ),
      // Lookbook routes removed — tab replaced by Outfitly AI.
      // GoRoute(
      //   path: '/lookbook',
      //   name: 'lookbook',
      //   builder: (context, state) => const LookbookScreen(),
      // ),
      // GoRoute(
      //   path: '/lookbook/:id',
      //   name: 'lookbookDetail',
      //   builder: (context, state) => LookbookDetailScreen(
      //     itemId: state.pathParameters['id']!,
      //   ),
      // ),

      // ── Checkout ──
      GoRoute(
        path: '/cart',
        name: 'cart',
        builder: (context, state) => CartScreen(
          payload: state.extra as OrderPayload?,
        ),
      ),
      GoRoute(
        path: '/checkout',
        name: 'checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/order-success',
        name: 'orderSuccess',
        builder: (context, state) => const OrderSuccessScreen(),
      ),

      // ── Tracking ──
      GoRoute(
        path: '/tracking/:orderId',
        name: 'tracking',
        builder: (context, state) => OrderTrackingScreen(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
    ],
  );
}
