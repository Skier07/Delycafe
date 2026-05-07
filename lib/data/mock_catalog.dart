import 'package:delycafe/models/catalog_item.dart';

const mockCatalog = [
  CatalogItem(
    id: 'pizza_1',
    title: 'Злодейка',
    category: 'Пицца',
    price: 825,
    image: 'assets/images/pizza/pizza-zlodejka.jpg',
    description:
        'Колбаски Баварские, мясной фарш, огурчики маринованные, лук красный маринованный, сыр, зелень, соусы Сальса и Фирменный',
    weight: '400 г.',
    isHit: true,
    isAvailable: true,
  ),
  CatalogItem(
      id: 'pizza_2',
      title: 'Цыпленок барбекю',
      category: 'Пицца',
      price: 820,
      image: 'assets/images/pizza/piczcza-czyiplyonok-barbekyu2.jpg',
      description:
          'Курица копченая, помидоры, соус BBQ, соус сливочно-чесночный, сыр, перец болгарский, красный лук, зелень'),
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
