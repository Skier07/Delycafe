from django.db import migrations, models

PHRASES = ['Счастье любит добавку', 'Планы на вечер? Поесть!', 'Сыр решает всё', 'Голод — плохой советчик', 'Хороший день начинается с «м-м-м»', 'На вкус лучше, чем на фото', 'Жизнь коротка. Бери десерт', 'Улыбка с доставкой', 'Сначала обед, потом подвиги', 'Твой животик уже выбрал', 'Есть повод. И без повода есть', 'Пицца — круг доверия', 'Любовь с первого кусочка', 'Работа подождёт. Обед — нет', 'Хрустим и не грустим', 'У счастья сырная корочка', 'Вкусно жить не запретишь', 'Каждому герою нужен обед', 'Пора подкрепить намерения', 'Еда — наш язык любви', 'Сегодня ты главный по вкусному', 'Пусть урчит только кот', 'Не откладывай вкусное на завтра', 'Ужин сам себя не закажет', 'Серьёзные планы на несерьёзный голод', 'Пармезан к хорошему настроению', 'Бургер в руке — радость в душе', 'Суперсила — вовремя поесть', 'Делу время, пицце — сейчас', 'Аппетит одобряет', 'Вкусный перерыв без совещаний', 'Салат тоже умеет радовать', 'Мысли о еде материализуются', 'Сделай паузу на пасту', 'Обед — уважительная причина', 'Тут можно влюбиться в начинку', 'Десерт — отдельный план', 'Кофе и никаких вопросов', 'Сырно, мирно, хорошо', 'Ещё кусочек — и за дела', 'Начинка важнее понедельника', 'Твой вкусный ход', 'Заходи на огонёк аппетита', 'Пятница начинается с заказа', 'Меньше суеты, больше еды', 'Блин, как вкусно!', 'Хорошие новости под соусом', 'Голодным здесь не место', 'Собери команду вкусняшек', 'Сегодня без грустного ужина']


def seed_phrases(apps, schema_editor):
    Phrase = apps.get_model('catalog', 'FoodPhrase')
    Phrase.objects.using(schema_editor.connection.alias).bulk_create([
        Phrase(text=text, sort_order=index) for index, text in enumerate(PHRASES)
    ])


class Migration(migrations.Migration):
    dependencies = [('catalog', '0012_image_variants')]
    operations = [
        migrations.CreateModel(
            name='FoodPhrase',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('text', models.CharField(max_length=100, verbose_name='Фраза')),
                ('is_active', models.BooleanField(default=True, verbose_name='Показывать в приложении')),
                ('sort_order', models.PositiveIntegerField(default=0, verbose_name='Порядок')),
            ],
            options={'ordering': ['sort_order', 'id'], 'verbose_name': 'Фраза про еду', 'verbose_name_plural': 'Фразы про еду'},
        ),
        migrations.RunPython(seed_phrases, migrations.RunPython.noop),
    ]
