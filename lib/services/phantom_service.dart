import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PhantomService {
  PhantomService._();
  static final PhantomService instance = PhantomService._();

  /// Fires after a wallet connects successfully
  final ValueNotifier<String?> lastConnectedWallet = ValueNotifier(null);

  /// Fires after a payment signature is received and verified
  final ValueNotifier<String?> lastPaymentSignature = ValueNotifier(null);

  static const String _appScheme = 'vela';
  static const String _appHost = 'phantom-callback';
  static const String _phantomBase = 'https://phantom.app/ul/v1';

  static const String cashMint = 'CASHx9KJUStyftLFWGvEVf59SGeG9sh5FfcnZMVPCASH';
  static const int cashDecimals = 6;

  // TODO: Replace with your actual treasury wallet address
  static const String treasuryWallet = 'YOUR_TREASURY_WALLET_ADDRESS_HERE';

  static const String _solanaRpc = 'https://api.mainnet-beta.solana.com';

  String _redirectUri(String action) {
    return '$_appScheme://$_appHost/$action';
  }

  Future<bool> connect() async {
    final params = {
      'app_url': 'https://usevela.app',
      'dapp_encryption_public_key': '',
      'redirect_link': _redirectUri('connect'),
      'cluster': 'mainnet-beta',
    };

    final uri = Uri.parse('$_phantomBase/connect').replace(queryParameters: params);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  String? parseConnectResponse(Uri uri) {
    if (uri.host != _appHost) return null;
    if (!uri.path.contains('connect')) return null;
    return uri.queryParameters['public_key'];
  }

  Future<double> getCashBalance(String walletAddress) async {
    try {
      final response = await http.post(
        Uri.parse(_solanaRpc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            walletAddress,
            {'mint': cashMint},
            {'encoding': 'jsonParsed'},
          ],
        }),
      );

      if (response.statusCode != 200) return 0.0;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = json['result'] as Map<String, dynamic>?;
      final accounts = result?['value'] as List<dynamic>?;

      if (accounts == null || accounts.isEmpty) return 0.0;

      final account = accounts[0] as Map<String, dynamic>;
      final info = account['account']?['data']?['parsed']?['info'] as Map<String, dynamic>?;
      final tokenAmount = info?['tokenAmount'] as Map<String, dynamic>?;
      final uiAmount = tokenAmount?['uiAmount'] as num?;

      return uiAmount?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Failed to fetch CASH balance: $e');
      return 0.0;
    }
  }

  Future<bool> requestPayment({required String serializedTransaction}) async {
    final params = {
      'dapp_encryption_public_key': '',
      'redirect_link': _redirectUri('sign'),
      'transaction': serializedTransaction,
    };

    final uri = Uri.parse('$_phantomBase/signAndSendTransaction')
        .replace(queryParameters: params);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  String? parseSignResponse(Uri uri) {
    if (uri.host != _appHost) return null;
    if (!uri.path.contains('sign')) return null;
    return uri.queryParameters['signature'];
  }

  Future<void> disconnect() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client
        .from('users')
        .update({'solana_wallet': null})
        .eq('user_id', userId);
  }

  Future<bool> isPhantomInstalled() async {
    final uri = Uri.parse('phantom://');
    return canLaunchUrl(uri);
  }
}
