import 'dart:convert';
import 'dart:typed_data';

import 'package:bs58/bs58.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pinenacl/x25519.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PhantomService {
  PhantomService._();
  static final PhantomService instance = PhantomService._();

  static const String _appScheme = 'vela';
  static const String _appHost = 'phantom-callback';
  static const String _phantomBase = 'https://phantom.app/ul/v1';

  static const String cashMint = 'CASHx9KJUStyftLFWGvEVf59SGeG9sh5FfcnZMVPCASH';
  static const int cashDecimals = 6;
  static const String treasuryWallet = 'YOUR_TREASURY_WALLET_ADDRESS_HERE';
  static const String _solanaRpc = 'https://api.mainnet-beta.solana.com';

  final ValueNotifier<String?> lastConnectedWallet = ValueNotifier(null);
  final ValueNotifier<String?> lastPaymentSignature = ValueNotifier(null);

  PrivateKey? _dappSecretKey;
  Uint8List? _dappPublicKey;
  Uint8List? _phantomPublicKey;
  String? _session;

  String _redirectUri(String action) {
    return '$_appScheme://$_appHost/$action';
  }

  void _generateKeypair() {
    _dappSecretKey = PrivateKey.generate();
    _dappPublicKey = Uint8List.fromList(_dappSecretKey!.publicKey.asTypedList);
  }

  Map<String, dynamic>? _decryptPayload({
    required String data,
    required String nonce,
  }) {
    try {
      // Phantom returns data and nonce as base58
      final encryptedData = base58.decode(data);
      final nonceBytes = base58.decode(nonce);

      final box = Box(
        myPrivateKey: _dappSecretKey!,
        theirPublicKey: PublicKey(_phantomPublicKey!),
      );

      final decrypted = box.decrypt(
        ByteList(encryptedData),
        nonce: nonceBytes,
      );

      final jsonStr = utf8.decode(decrypted);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Phantom decrypt error: $e');
      return null;
    }
  }

  Future<bool> connect() async {
    _generateKeypair();

    final params = {
      'app_url': 'https://usevela.app',
      'dapp_encryption_public_key': base58.encode(_dappPublicKey!),
      'redirect_link': _redirectUri('connect'),
      'cluster': 'mainnet-beta',
    };

    final uri = Uri.parse('$_phantomBase/connect')
        .replace(queryParameters: params);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  String? parseConnectResponse(Uri uri) {
    if (uri.host != _appHost) return null;
    if (!uri.path.contains('connect')) return null;

    final errorCode = uri.queryParameters['errorCode'];
    if (errorCode != null) {
      debugPrint('Phantom connect error: $errorCode - ${uri.queryParameters['errorMessage']}');
      return null;
    }

    // Phantom returns its encryption public key as base58
    final phantomPubKeyB58 = uri.queryParameters['phantom_encryption_public_key'];
    if (phantomPubKeyB58 == null) return null;
    _phantomPublicKey = base58.decode(phantomPubKeyB58);

    final data = uri.queryParameters['data'];
    final nonce = uri.queryParameters['nonce'];
    if (data == null || nonce == null) return null;

    final payload = _decryptPayload(data: data, nonce: nonce);
    if (payload == null) return null;

    _session = payload['session'] as String?;
    final publicKey = payload['public_key'] as String?;

    debugPrint('Phantom connected wallet: $publicKey');
    return publicKey;
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
      final info = account['account']?['data']?['parsed']?['info']
          as Map<String, dynamic>?;
      final tokenAmount = info?['tokenAmount'] as Map<String, dynamic>?;
      final uiAmount = tokenAmount?['uiAmount'] as num?;

      return uiAmount?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Failed to fetch CASH balance: $e');
      return 0.0;
    }
  }

  Future<bool> requestPayment({required String serializedTransaction}) async {
    if (_session == null || _dappSecretKey == null || _phantomPublicKey == null) {
      debugPrint('Phantom session not established. Connect wallet first.');
      return false;
    }

    // Encrypt the payload for Phantom
    final nonce = _generateNonce();
    final payloadJson = jsonEncode({
      'session': _session,
      'transaction': serializedTransaction,
    });

    final box = Box(
      myPrivateKey: _dappSecretKey!,
      theirPublicKey: PublicKey(_phantomPublicKey!),
    );

    final encrypted = box.encrypt(
      Uint8List.fromList(utf8.encode(payloadJson)),
      nonce: nonce,
    );

    final params = {
      'dapp_encryption_public_key': base58.encode(_dappPublicKey!),
      'redirect_link': _redirectUri('sign'),
      'nonce': base58.encode(Uint8List.fromList(nonce)),
      'payload': base58.encode(Uint8List.fromList(encrypted.cipherText)),
    };

    final uri = Uri.parse('$_phantomBase/signAndSendTransaction')
        .replace(queryParameters: params);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Uint8List _generateNonce() {
    // 24-byte nonce for NaCl box
    final nonce = Uint8List(24);
    final now = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < 24; i++) {
      nonce[i] = (now >> (i % 8)) & 0xFF;
    }
    return nonce;
  }

  String? parseSignResponse(Uri uri) {
    if (uri.host != _appHost) return null;
    if (!uri.path.contains('sign')) return null;

    final errorCode = uri.queryParameters['errorCode'];
    if (errorCode != null) {
      debugPrint('Phantom sign error: $errorCode - ${uri.queryParameters['errorMessage']}');
      return null;
    }

    final data = uri.queryParameters['data'];
    final nonce = uri.queryParameters['nonce'];

    if (data != null && nonce != null && _phantomPublicKey != null) {
      final payload = _decryptPayload(data: data, nonce: nonce);
      return payload?['signature'] as String?;
    }

    return uri.queryParameters['signature'];
  }

  Future<void> disconnect() async {
    _dappSecretKey = null;
    _dappPublicKey = null;
    _phantomPublicKey = null;
    _session = null;

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