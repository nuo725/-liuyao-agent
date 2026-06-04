import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../state/auth_state.dart';
import 'password_recovery_screen.dart';

class LoginGateScreen extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;

  const LoginGateScreen({
    super.key,
    this.title = '登录 / 注册',
    this.subtitle = '登录后可继续追问、查看完整解读并同步记录。',
  });

  @override
  ConsumerState<LoginGateScreen> createState() => _LoginGateScreenState();
}

class _LoginGateScreenState extends ConsumerState<LoginGateScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  int _countdown = 0;
  bool _agreed = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_ensureAgreement()) return;
    setState(() {
      _countdown = 10;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('测试模式：验证码已发送（模拟）。')));
  }

  bool _ensureAgreement() {
    if (_agreed) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先勾选《用户协议》和《隐私政策》。')));
    return false;
  }

  Future<void> _loginByPhone() async {
    if (!_ensureAgreement()) return;
    // TODO(Backend Integration)[auth_api#agreement-consent]: 当前仅做本地协议勾选门禁，后续改为服务端存证。
    // TODO(Backend Integration)[auth_api#test-login]: 当前为 UI 测试模式，后续接入真实验证码校验。
    final rawPhone = _phoneController.text.trim();
    final rawCode = _codeController.text.trim();

    final phone = rawPhone.isEmpty ? '13800138000' : rawPhone;
    final code = rawCode.isEmpty ? '000000' : rawCode;

    await ref.read(authStateProvider.notifier).loginWithPhone(phone, code);
    _finishIfLoggedIn();
  }

  Future<void> _socialLoginWechat() async {
    if (!_ensureAgreement()) return;
    // TODO(Backend Integration)[auth_api#social-login-wechat]: 当前模拟授权成功，后续接微信 SDK 授权码。
    await ref
        .read(authStateProvider.notifier)
        .loginWithWechat('wechat-mock-code');
    _finishIfLoggedIn();
  }

  Future<void> _socialLoginQQ() async {
    if (!_ensureAgreement()) return;
    // TODO(Backend Integration)[auth_api#social-login-qq]: 当前模拟授权成功，后续接 QQ SDK 授权码。
    await ref.read(authStateProvider.notifier).loginWithQQ('qq-mock-code');
    _finishIfLoggedIn();
  }

  void _finishIfLoggedIn() {
    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    if (auth.isLoggedIn) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(auth.error ?? '登录失败，请稍后重试。')));
  }

  void _openAgreement(String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AgreementPage(
          title: title,
          content: title == '用户协议' ? _kUserAgreement : _kPrivacyPolicy,
        ),
      ),
    );
  }

  static const _kUserAgreement = '''宽窄·Orbit 用户协议（模拟版本 v1.0）

更新日期：2026 年 4 月 15 日
生效日期：2026 年 4 月 15 日

一、服务条款概述
欢迎使用宽窄·Orbit（以下简称"本应用"）。本应用由宽窄·Orbit 团队开发运营。在您注册、登录或使用本应用前，请仔细阅读本协议。

二、用户注册
2.1 您在注册时应提供真实、准确、完整的个人信息。
2.2 每位用户仅可注册一个账号，不得转让、借用或分享。

三、使用规则
3.1 您不得利用本应用从事违法违规活动。
3.2 社区发布内容需遵守社区规范，不得发布违规、侵权或不当内容。
3.3 本应用中的六爻仪式为文化体验功能，不构成任何形式的占卜、预测或决策建议。

四、知识产权
本应用的所有内容（包括但不限于文字、图片、界面设计、程序代码）的知识产权归本应用所有。

五、免责声明
5.1 本应用仅提供情绪承接和社区互动服务，不对任何基于内容做出的个人决策负责。
5.2 因网络、设备等不可控因素导致的服务中断，本应用不承担责任。

六、账号注销
您有权随时申请注销账号。注销后，您的数据将被永久删除且不可恢复。

七、协议修改
我们保留随时修改本协议的权利，修改后将通过应用内通知您。

正式上线前将由法务审核通过的正式版本替换，并在登录接口记录用户同意的协议版本号和时间戳。''';

  static const _kPrivacyPolicy = '''宽窄·Orbit 隐私政策（模拟版本 v1.0）

更新日期：2026 年 4 月 15 日
生效日期：2026 年 4 月 15 日

一、信息收集
我们可能收集以下信息：
• 注册信息：手机号、昵称、头像
• 设备信息：设备型号、操作系统版本
• 使用信息：仪式记录、社区互动行为
• 传感器数据：加速度计（仅用于摇一摇功能，不存储原始数据）

二、信息使用
收集的信息仅用于：
• 提供核心服务（仪式解读、社区互动、同频匹配）
• 改善用户体验和产品质量
• 保障账号安全

三、信息存储
• 您的数据存储在中国境内的合规云服务器中
• 我们采用加密传输和存储措施保护您的数据
• 仪式记录和对话内容仅您本人可见

四、信息共享
我们不会向任何第三方出售您的个人信息。仅在以下情况可能共享：
• 获得您的明确同意
• 依据法律法规的要求

五、用户权利
您有权：
• 查看和修改您的个人信息
• 删除您的内容和互动记录
• 注销账号并删除所有数据
• 关闭个性化推荐

六、未成年人保护
本应用不面向 14 周岁以下用户。如发现未成年人使用，请联系我们处理。

七、联系我们
如有隐私相关问题，请联系：privacy@orbit-app.com

正式上线前将由合规审核通过的正式版本替换，并在用户同意时记录时间戳。''';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 52, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDFD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                ),
                child: Column(
                  children: [
                    _InputRow(
                      icon: Icons.phone_iphone_rounded,
                      hintText: '手机号（测试可任意输入）',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    Divider(height: 22, color: AppColors.border),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: Color(0xFF6B6B6B),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: '验证码（测试可任意输入）',
                              hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _countdown > 0 ? null : _sendCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _countdown > 0
                                  ? const Color(0xFFF5F5F5)
                                  : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _countdown > 0 ? '${_countdown}s' : '获取验证码',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _countdown > 0
                                    ? const Color(0xFFAAAAAA)
                                    : const Color(0xFF6B6B6B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    activeColor: AppColors.primary,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: '我已阅读并同意'),
                            TextSpan(
                              text: '《用户协议》',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openAgreement('用户协议'),
                            ),
                            const TextSpan(text: '与'),
                            TextSpan(
                              text: '《隐私政策》',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openAgreement('隐私政策'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _loginByPhone,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    auth.isLoading ? '登录中...' : '手机号一键登录',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : _socialLoginWechat,
                      icon: const Icon(
                        Icons.mark_chat_unread_outlined,
                        size: 18,
                      ),
                      label: const Text('微信登录'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : _socialLoginQQ,
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('QQ登录'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PasswordRecoveryScreen(),
                        ),
                      );
                    },
                    child: Text(
                      '找回密码',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      '暂不登录，返回',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final IconData icon;
  final String hintText;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _InputRow({
    required this.icon,
    required this.hintText,
    required this.controller,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B6B6B)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _AgreementPage extends StatelessWidget {
  final String title;
  final String content;

  const _AgreementPage({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(content, style: const TextStyle(fontSize: 14, height: 1.8)),
      ),
    );
  }
}
