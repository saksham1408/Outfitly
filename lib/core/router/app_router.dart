import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../network/supabase_client.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
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
import '../../features/measurements/presentation/ai_scanner/ai_scan_intro_screen.dart';
import '../../features/measurements/presentation/ai_scanner/ai_camera_screen.dart';
import '../../features/measurements/presentation/ai_scanner/ai_scanning_screen.dart';
import '../../features/measurements/presentation/ai_scanner/ai_measurement_review_screen.dart';
import '../../features/checkout/cart_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/order_success_screen.dart';
import '../../features/tracking/screens/order_tracking_screen.dart';
import '../../features/tracking/screens/orders_screen.dart';
import '../../features/measurements/presentation/tailor_visit_tracking_screen.dart';
import '../../features/look_recreator/presentation/recreate_look_screen.dart';
import '../../features/look_recreator/presentation/analyzing_look_screen.dart';
import '../../features/look_recreator/presentation/recreated_design_studio_screen.dart';
import '../../features/virtual_try_on/presentation/virtual_try_on_screen.dart';
import '../../features/catalog/models/product_model.dart';
import '../../features/outfitly_ai/presentation/outfitly_ai_screen.dart';
import '../../features/wardrobe_calendar/presentation/wardrobe_calendar_screen.dart';
import '../../features/wardrobe_calendar/presentation/wardrobe_inventory_screen.dart';
import '../../features/wardrobe_calendar/presentation/outfit_planner_screen.dart';
import '../../features/wardrobe_calendar/presentation/add_event_screen.dart';
import '../../features/wardrobe_calendar/domain/planner_event.dart';
import '../../features/shell/main_shell.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/wishlist/screens/wishlist_screen.dart';
import '../../features/account/presentation/add_address_screen.dart';
import '../../features/addresses/domain/address_prefill.dart';
import '../../features/digital_wardrobe/presentation/digital_closet_screen.dart';
import '../../features/digital_wardrobe/presentation/wardrobe_upload_screen.dart';
import '../../features/digital_wardrobe/presentation/daily_stylist_screen.dart';
import '../../features/digital_wardrobe/presentation/style_anchor_screen.dart';
import '../../features/social_wardrobe/presentation/social_dashboard_screen.dart';
import '../../features/social_wardrobe/presentation/friend_closet_screen.dart';
import '../../features/social_wardrobe/presentation/borrow_requests_screen.dart';

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
    // Cold launch always starts on the animated splash. The splash
    // itself decides (after 3s) whether the user lands on /home or
    // /login based on their Supabase session.
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final session = AppSupabase.client.auth.currentSession;
      final loggedIn = session != null;
      final path = state.matchedLocation;

      // Splash is auth-agnostic — we never redirect away from it.
      // Letting it render unconditionally avoids a flicker where the
      // router would punt signed-in users straight to /home.
      if (path == '/') return null;

      if (!loggedIn && !_publicRoutes.contains(path)) return '/login';
      if (loggedIn && _publicRoutes.contains(path)) return '/home';

      return null;
    },
    routes: [
      // ── Splash ──
      // The very first screen on launch. Uses `context.go('/home')` or
      // `/login` after its 3-second timer to REPLACE itself in the
      // stack — so the back gesture can never return here.
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

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

      // ── AI Body Scanner ──
      GoRoute(
        path: '/measurements/ai-scan-intro',
        name: 'aiScanIntro',
        builder: (context, state) => AiScanIntroScreen(
          payload: state.extra as OrderPayload?,
        ),
      ),
      GoRoute(
        path: '/measurements/ai-scan-camera',
        name: 'aiScanCamera',
        builder: (context, state) => AiCameraScreen(
          payload: state.extra as OrderPayload?,
        ),
      ),
      GoRoute(
        path: '/measurements/ai-scan-scanning',
        name: 'aiScanScanning',
        builder: (context, state) => AiScanningScreen(
          payload: state.extra as AiScanPayload,
        ),
      ),
      GoRoute(
        path: '/measurements/ai-scan-review',
        name: 'aiScanReview',
        builder: (context, state) => AiMeasurementReviewScreen(
          payload: state.extra as AiReviewPayload,
        ),
      ),

      // ── Outfitly AI (replaces Lookbook tab) ──
      GoRoute(
        path: '/outfitly-ai',
        name: 'outfitlyAi',
        builder: (context, state) => const OutfitlyAiScreen(),
      ),

      // ── Wishlist ──
      GoRoute(
        path: '/wishlist',
        name: 'wishlist',
        builder: (context, state) => const WishlistScreen(),
      ),

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
        // `tailorVisitId` is only present when the order was placed
        // with a home-tailor-visit. The success screen reads it to
        // surface a "TRACK TAILOR VISIT" CTA that deep-links into
        // the Realtime tracker — without it, the customer would
        // never see the Partner app's status updates flow through.
        builder: (context, state) => OrderSuccessScreen(
          tailorVisitId: state.uri.queryParameters['tailorVisitId'],
        ),
      ),

      // ── Wardrobe Calendar & Planner ──
      GoRoute(
        path: '/wardrobe',
        name: 'wardrobe',
        builder: (context, state) => const WardrobeInventoryScreen(),
      ),
      GoRoute(
        path: '/wardrobe/calendar',
        name: 'wardrobeCalendar',
        builder: (context, state) => const WardrobeCalendarScreen(),
      ),
      GoRoute(
        path: '/wardrobe/planner',
        name: 'wardrobePlanner',
        builder: (context, state) => OutfitPlannerScreen(
          event: state.extra as PlannerEvent,
        ),
      ),
      GoRoute(
        path: '/wardrobe/add-event',
        name: 'wardrobeAddEvent',
        builder: (context, state) => AddEventScreen(
          initialDate: state.extra is DateTime ? state.extra as DateTime : null,
        ),
      ),

      // ── Tracking ──
      // Standalone Orders route — same screen the MainShell renders
      // as the 5th bottom-nav tab, but reachable from anywhere via
      // a normal push (e.g. the Profile screen's "Order History"
      // tile). Re-using the screen instead of forking it means the
      // tabbed Orders/Tailor Visits split is consistent everywhere.
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/tracking/:orderId',
        name: 'tracking',
        builder: (context, state) => OrderTrackingScreen(
          orderId: state.pathParameters['orderId']!,
        ),
      ),

      // ── Home Tailor Visit — live tracker for a single
      //    tailor_appointments row. Customer lands here after
      //    tapping "REQUEST TAILOR VISIT" on the booking screen;
      //    the screen streams status changes in real time so when
      //    a Partner accepts, the "YOUR TAILOR" card fills in
      //    with their name and years of experience.
      GoRoute(
        path: '/tailor-visit/:id',
        name: 'tailorVisit',
        builder: (context, state) => TailorVisitTrackingScreen(
          appointmentId: state.pathParameters['id']!,
        ),
      ),

      // ── AI Look Recreator (Gemini Vision) ──
      // Three-screen flow:
      //   1. /recreate-look          → upload + budget/occasion chips
      //   2. /recreate-look/analyzing → laser-scan animation + Gemini call
      //   3. /recreate-look/result   → recreated design studio
      // Each step `pushReplacement`s to the next so the back gesture
      // skips transient surfaces and lands on Home.
      GoRoute(
        path: '/recreate-look',
        name: 'recreateLook',
        builder: (context, state) => const RecreateLookScreen(),
      ),
      GoRoute(
        path: '/recreate-look/analyzing',
        name: 'recreateLookAnalyzing',
        builder: (context, state) => AnalyzingLookScreen(
          request: state.extra as RecreateLookRequest,
        ),
      ),
      GoRoute(
        path: '/recreate-look/result',
        name: 'recreateLookResult',
        builder: (context, state) => RecreatedDesignStudioScreen(
          result: state.extra as RecreatedDesignResult,
        ),
      ),

      // ── AR Virtual Try-On ──
      GoRoute(
        path: '/virtual-try-on',
        name: 'virtualTryOn',
        builder: (context, state) => VirtualTryOnScreen(
          product: state.extra as ProductModel,
        ),
      ),

      // ── Account: Add / manage delivery addresses ──
      GoRoute(
        path: '/account/add-address',
        name: 'addAddress',
        builder: (context, state) => AddAddressScreen(
          prefill: state.extra is AddressPrefill
              ? state.extra as AddressPrefill
              : null,
        ),
      ),

      // ── Digital Wardrobe + Daily AI Stylist ──
      // Personal digital closet (photograph → categorize → store in
      // Supabase). Feeds the Daily Stylist so Gemini only recommends
      // clothes the user actually owns.
      GoRoute(
        path: '/digital-wardrobe/closet',
        name: 'digitalCloset',
        builder: (context, state) => const DigitalClosetScreen(),
      ),
      GoRoute(
        path: '/digital-wardrobe/upload',
        name: 'digitalWardrobeUpload',
        builder: (context, state) => const WardrobeUploadScreen(),
      ),
      GoRoute(
        path: '/digital-wardrobe/stylist',
        name: 'dailyStylist',
        builder: (context, state) => const DailyStylistScreen(),
      ),
      // Style an uploaded anchor piece — AI Vision designs 3 full
      // outfits around a single garment the user photographs.
      GoRoute(
        path: '/digital-wardrobe/style-anchor',
        name: 'styleAnchor',
        builder: (context, state) => const StyleAnchorScreen(),
      ),

      // ── Friend Closet Sharing ──
      // The "My Network" social entry point. Users discover and add
      // friends here, see a horizontal row of accepted friends'
      // avatars, and tap into the friend-closet view at the route
      // below. Activity feed lives on the dashboard too.
      GoRoute(
        path: '/social',
        name: 'socialDashboard',
        builder: (context, state) => const SocialDashboardScreen(),
      ),
      GoRoute(
        path: '/friend-closet/:friendId',
        name: 'friendCloset',
        builder: (context, state) => FriendClosetScreen(
          friendId: state.pathParameters['friendId']!,
        ),
      ),
      GoRoute(
        path: '/borrow-requests',
        name: 'borrowRequests',
        builder: (context, state) => const BorrowRequestsScreen(),
      ),
    ],
  );
}
