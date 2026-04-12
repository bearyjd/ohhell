import 'package:ohhell_protocol/ohhell_protocol.dart';

void main() {
  // Example: create and serialize a client message
  const msg = JoinRoomMessage(playerName: 'Alice');
  final json = msg.toJson();
  print('Serialized: $json');

  final decoded = ClientMessage.fromJson(json);
  print('Decoded: ${decoded.runtimeType}');
}
