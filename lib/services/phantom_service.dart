import 'dart:convert';
import 'dart:typed_data';

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

  /// Fires after a wallet connects successfully
  final ValueNotifier<String?> lastConnectedWallet = ValueNotifier(null);

  /// Fires after a payment signature is received and verified
  final ValueNotifier<String?> lastPaymentSignature = ValueNotifier(null);

  // Ephemeral X25519 keypair for encrypted Phantom sessions
  PrivateKey? _dappSecretKey;
  Uint8List? _dappPublicKey;

  // Phantom's X25519 public key (received on connect)
  Uint8List? _phantomPublicKey;

  // Shared secret for decryption
  Uint8List? _sharedSecret;

  // Session token from Phantom
  String? _session;

  String _redirectUri(String action) {
    return '$_appScheme://$_appHost/$action';
  }

  void _generateKeypair() {
    _dappSecretKey = PrivateKey.generate();
    _dappPublicKey = Uint8List.fromList(_dappSecretKey!.publicKey.asTypedList);
  }

  Uint8List _computeSharedSecret(Uint8List phantomPubKey) {
    final box = Box(
      myPrivateKey: _dappSecretKey!,
      theirPublicKey: PublicKey(phantomPubKey),
    );
    // pinenacl Box uses the shared secret internally;
    // we store the phantom key and decrypt using the Box directly
    return phantomPubKey;
  }

  Map<String, dynamic>? _decryptPayload({
    required String data,
    required String nonce,
  }) {
    try {
      final encryptedData = base64Decode(data);
      final nonceBytes = base64Decode(nonce);

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
      'dapp_encryption_public_key': base64Encode(_dappPublicKey!),
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

    // Check for error
    final errorCode = uri.queryParameters['errorCode'];
    if (errorCode != null) {
      debugPrint('Phantom connect error: $errorCode - ${uri.queryParameters['errorMessage']}');
      return null;
    }

    // Store Phantom's encryption public key
    final phantomPubKeyBase64 = uri.queryParameters['phantom_encryption_public_key'];
    if (phantomPubKeyBase64 == null) return null;
    _phantomPublicKey = base64Decode(phantomPubKeyBase64);

    // Decrypt the data payload to get the actual wallet public_key + session
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

    final params = {
      'dapp_encryption_public_key': base64Encode(_dappPublicKey!),
      'redirect_link': _redirectUri('sign'),
      'nonce': base64Encode(_generateNonce()),
      'payload': base64Encode(utf8.encode(jsonEncode({
        'session': _session,
        'transaction': serializedTransaction,
      }))),
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
    for (var i = 0; i < 24; i++) {
      nonce[i] = DateTime.now().microsecondsSinceEpoch % 256;
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

    // For signAndSendTransaction, Phantom returns the signature
    // In encrypted flow, it's in the data payload
    final data = uri.queryParameters['data'];
    final nonce = uri.queryParameters['nonce'];

    if (data != null && nonce != null && _phantomPublicKey != null) {
      final payload = _decryptPayload(data: data, nonce: nonce);
      return payload?['signature'] as String?;
    }

    // Fallback for non-encrypted response
    return uri.queryParameters['signature'];
  }

  Future<void> disconnect() async {
    _dappSecretKey = null;
    _dappPublicKey = null;
    _phantomPublicKey = null;
    _sharedSecret = null;
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