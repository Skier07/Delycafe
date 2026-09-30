enum ProductSizeFeedback {
  small(.86),
  medium(.93),
  large(1),
  regular(1);

  const ProductSizeFeedback(this.imageScale);
  final double imageScale;

  static ProductSizeFeedback fromTitle(String? title) {
    final value = (title ?? '').trim().toLowerCase();
    if (value.startsWith('маленьк') || value.startsWith('малой')) return small;
    if (value.startsWith('средн')) return medium;
    if (value.startsWith('больш')) return large;
    return regular;
  }
}
