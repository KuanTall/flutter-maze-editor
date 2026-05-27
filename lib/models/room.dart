class Room {
  final int x;
  final int y;

  bool north;
  bool east;
  bool south;
  bool west;

  Room({
    required this.x,
    required this.y,
    this.north = false,
    this.east = false,
    this.south = false,
    this.west = false,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      x: json['x'] as int,
      y: json['y'] as int,
      north: json['north'] as bool? ?? false,
      east: json['east'] as bool? ?? false,
      south: json['south'] as bool? ?? false,
      west: json['west'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'north': north,
      'east': east,
      'south': south,
      'west': west,
    };
  }
}
