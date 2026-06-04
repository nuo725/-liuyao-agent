/// 应用间距系统
class AppSpacing {
  AppSpacing._();

  // 基础间距单位（基于8的倍数）
  static const double unit = 4.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // 页面边距
  static const double pageHorizontal = 20.0;  // 收紧：24→20
  static const double pageVertical = 24.0;

  // 内容密度系数（>1 = 更紧凑但不死板）
  static const double contentDensity = 1.1;

  // 卡片间距
  static const double cardPadding = 16.0;
  static const double cardMargin = 12.0;
  static const double cardRadius = 16.0;

  // 按钮尺寸
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonRadius = 12.0;
  static const double buttonIconSize = 20.0;

  // 输入框
  static const double inputHeight = 52.0;
  static const double inputRadius = 12.0;

  // 导航栏
  static const double navBarHeight = 60.0;
  static const double tabBarHeight = 44.0;

  // 头像
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 48.0;
  static const double avatarLarge = 80.0;

  // 图标
  static const double iconSmall = 16.0;
  static const double iconMedium = 22.0;  // 缩小：24→22，更内敛
  static const double iconLarge = 32.0;

  // 动画时间（毫秒）
  static const int animFast = 150;
  static const int animNormal = 300;
  static const int animSlow = 500;
  static const int animVerySlow = 800;
}
