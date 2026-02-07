String generateRoomCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  final now = DateTime.now().millisecondsSinceEpoch;
  final buf = StringBuffer();
  int seed = now;
  for (int i = 0; i < 6; i++) {
    seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
    buf.write(chars[seed % chars.length]);
  }
  return buf.toString();
}
