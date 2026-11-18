import 'package:flutter_dotenv/flutter_dotenv.dart';

class BlockchainConfig {
  static String get rpcUrl => dotenv.env['RPC_URL'] ?? '';
  static String get privateKey => dotenv.env['PRIVATE_KEY'] ?? '';
  static String get contractAddress => dotenv.env['CONTRACT_ADDRESS'] ?? '';
  static const int chainId = 11155111; // Chain ID Sepolia Testnet[cite: 2, 5]
}
