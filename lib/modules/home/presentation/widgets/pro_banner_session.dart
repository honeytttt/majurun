/// Shared dismissal state for all promo banners in the feed.
/// Dismissing any one banner (top strip or mid-feed card) hides them all.
class ProBannerSession {
  static bool dismissed = false;
}
