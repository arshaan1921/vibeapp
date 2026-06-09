class CameraFilter {
  final String name;
  final List<double> matrix;

  const CameraFilter({
    required this.name,
    required this.matrix,
  });

  static const List<CameraFilter> filters = [
    CameraFilter(
      name: "Normal",
      matrix: [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    CameraFilter(
      name: "Warm",
      matrix: [
        1.2, 0.1, 0, 0, 0,
        0, 1.1, 0, 0, 0,
        0, 0, 0.9, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    CameraFilter(
      name: "Cool",
      matrix: [
        0.9, 0, 0, 0, 0,
        0, 1.1, 0, 0, 0,
        0, 0.1, 1.2, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    CameraFilter(
      name: "Vintage",
      matrix: [
        0.9, 0.5, 0.1, 0, 0,
        0.3, 0.8, 0.1, 0, 0,
        0.2, 0.3, 0.5, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    CameraFilter(
      name: "B&W",
      matrix: [
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    CameraFilter(
      name: "Vibrant",
      matrix: [
        1.3, -0.1, -0.1, 0, 0,
        -0.1, 1.3, -0.1, 0, 0,
        -0.1, -0.1, 1.3, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
  ];
}
