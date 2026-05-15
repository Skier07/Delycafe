import 'package:delycafe/models/catalog_item.dart';

const mockCatalog = [
  CatalogItem(
    id: 'pizza_1',
    title: 'Злодейка',
    category: 'Пицца',
    price: 820,
    image: 'assets/images/pizza/pizza-zlodejka.jpg',
    description:
        'Колбаски Баварские, мясной фарш, огурчики маринованные, лук красный маринованный, сыр, зелень, соусы Сальса и Фирменный',
    isHit: true,
    isAvailable: true,
    variants: const [
      ProductVariant(
        id: 'small',
        title: 'Маленькая',
        price: 495,
        weight: '400 г.',
      ),
      ProductVariant(
        id: 'medium',
        title: 'Средняя',
        price: 825,
        weight: '700 г.',
      ),
      ProductVariant(
        id: 'large',
        title: 'Большая',
        price: 1100,
        weight: '1050 г.',
      ),
    ],
  ),
  CatalogItem(
    id: 'pizza_2',
    title: 'Цыпленок барбекю',
    category: 'Пицца',
    price: 820,
    image: 'assets/images/pizza/piczcza-czyiplyonok-barbekyu2.jpg',
    description:
        'Курица копченая, помидоры, соус BBQ, соус сливочно-чесночный, сыр, перец болгарский, красный лук, зелень',
    variants: const [
      ProductVariant(
        id: 'small',
        title: 'Маленькая',
        price: 490,
        weight: '400 г.',
      ),
      ProductVariant(
        id: 'medium',
        title: 'Средняя',
        price: 820,
        weight: '700 г.',
      ),
      ProductVariant(
        id: 'large',
        title: 'Большая',
        price: 1100,
        weight: '1050 г.',
      ),
    ],
  ),
  CatalogItem(
    id: 'pizza_3',
    title: 'Пикантный лосось',
    category: 'Пицца',
    price: 1130,
    image: 'assets/images/pizza/piczcza-pikantnyij-losos.jpg',
    description:
        'Лосось, cливочный соус, соус Спайси, сыр Голландский, сыр Моцарелла, оливки, зелень',
    isHit: true,
    isNew: true,
    variants: const [
      ProductVariant(
        id: 'small',
        title: 'Маленькая',
        price: 690,
        weight: '400 г.',
      ),
      ProductVariant(
        id: 'medium',
        title: 'Средняя',
        price: 1130,
        weight: '700 г.',
      ),
      ProductVariant(
        id: 'large',
        title: 'Большая',
        price: 1500,
        weight: '1080 г.',
      ),
    ],
  ),
  CatalogItem(
    id: 'pizza_4',
    title: 'Пицца Угорь с Унаги',
    category: 'Пицца',
    price: 1120,
    image: 'assets/images/pizza/pizza-unagi.jpg',
    description:
        'Жареный угорь, томат, сыр сливочный, сыр Моцарелла, салат Чука, сливочно-чесночный соус, соус Унаги, зелень',
    isHit: true,
    isNew: true,
    variants: const [
      ProductVariant(
        id: 'medium',
        title: 'Средняя',
        price: 1120,
        weight: '750 г.',
      ),
      ProductVariant(
        id: 'large',
        title: 'Большая',
        price: 1500,
        weight: '1100 г.',
      ),
    ],
  ),
  CatalogItem(
    id: 'pizza_5',
    title: 'Пицца «Маркиза»',
    category: 'Пицца',
    price: 820,
    image: 'assets/images/pizza/35.jpg',
    description:
        'Сервелат элитный, курочка варено-копченая, томат, кетчуп, соус фирменный, сыр Голландский, сыр Моцарелла, оливки, зелень',
    isNew: true,
    variants: const [
      ProductVariant(
        id: 'small',
        title: 'Маленькая',
        price: 500,
        weight: '400 г.',
      ),
      ProductVariant(
        id: 'medium',
        title: 'Средняя',
        price: 820,
        weight: '700 г.',
      ),
      ProductVariant(
        id: 'large',
        title: 'Большая',
        price: 1100,
        weight: '1050 г.',
      ),
    ],
  ),
  CatalogItem(
    id: 'pizza_6',
    title: 'Пицца «Жгучая чика»',
    category: 'Пицца',
    price: 810,
    image: 'assets/images/pizza/piczcza-zhguchaya-chika2.jpg',
    description:
        'Соус жгуче-острый Сальса, копченая куриная грудка, острый перец Халапеньо, шампиньоны, помидоры, болгарский перец, сыр, оливки, зелень',
    isHit: true,
    variants: const [
      ProductVariant(
        id: 'small',
        title: 'Маленькая',
        price: 490,
        weight: '400 г.',
      ),
      ProductVariant(
        id: 'medium',
        title: 'Средняя',
        price: 810,
        weight: '700 г.',
      ),
      ProductVariant(
        id: 'large',
        title: 'Большая',
        price: 1080,
        weight: '1050 г.',
      ),
    ],
  ),
  CatalogItem(
    id: 'pizza_7',
    title: 'Пицца «Корона»',
    category: 'Пицца',
    price: 790,
    weight: '700 г.',
    image: 'assets/images/pizza/piczcza-korona.jpg',
    description:
        'Копченая курочка, кукуруза, болгарский перчик, сыр, томаты, сливочно-чесночный соус, оливки, зелень',
    variants: const [
      ProductVariant(
        id: 'small',
        title: 'Маленькая',
        price: 485,
        weight: '400 г.',
      ),
      ProductVariant(
        id: 'medium',
        title: 'Средняя',
        price: 790,
        weight: '700 г.',
      ),
      ProductVariant(
        id: 'large',
        title: 'Большая',
        price: 1050,
        weight: '1050 г.',
      ),
    ],
  ),
  CatalogItem(
    id: 'shaurma_1',
    title: 'Шаурма Кесадилья',
    category: 'Шаурма',
    price: 280,
    image: 'assets/images/shaurma/kesadilya2.jpg',
    description:
        'Обжаренная пшеничная лепешка, наполненная сыром. Ветчина, грибочки, помидоры и сливочно-чесночный соус.',
  ),
  CatalogItem(
    id: 'shaurma_2',
    title: 'Шаурма Шашлычная',
    category: 'Шаурма',
    price: 340,
    image: 'assets/images/shaurma/shaurma1-min.jpg',
    description:
        'В мягком лаваше: мясо свинины-шашлык, свежая капуста, корейская морковь, помидоры, маринованные огурцы, фирменный соус, зелень.',
    isHit: true,
  ),
  CatalogItem(
    id: 'drink_1',
    title: 'Капучино',
    category: 'Напитки',
    price: 140,
    image: 'assets/images/coffe/kofe-kapuchino1.jpg',
    description: 'Кофе Капучино, 200 мл',
  ),
  CatalogItem(
    id: 'drink_2',
    title: 'Кофе Латтэ',
    category: 'Напитки',
    price: 160,
    image: 'assets/images/coffe/kofe-latte2.jpg',
    description: 'Ароматный Латтэ, 200 мл',
  ),
  CatalogItem(
    id: 'burger_1',
    title: 'Бургер «Гавайский»',
    category: 'Бургеры',
    price: 430,
    image: 'assets/images/burger/burger-gavajskij1.jpg',
    description:
        'Булочка с кунжутом обжаренная, куриная грудка жаренная, пекинская капуста, ананас, лук красный маринованный, сливочно-чесночный соус, сыр.',
  ),
];
