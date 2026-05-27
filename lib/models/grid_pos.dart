class GridPos {
  final int x;
  final int y;

  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
