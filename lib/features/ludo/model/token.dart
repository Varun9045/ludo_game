enum TokenStatus { home, path, homePath, finished }

class TokenState {
  TokenState(this.player, this.id);

  final String player;
  final int id;
  TokenStatus status = TokenStatus.home;
  int steps = 0;
  int homeStep = 0;
}
