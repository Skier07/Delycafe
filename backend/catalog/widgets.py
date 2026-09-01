import json

from django import forms
from django.forms.widgets import Widget

from catalog.info_content import empty_content, parse_content


class InfoContentWidget(Widget):
    template_name = 'admin/catalog/info_content_widget.html'

    class Media:
        css = {
            'all': ('catalog/admin/info_content_editor.css',),
        }
        js = ('catalog/admin/info_content_editor.js',)

    def format_value(self, value):
        if not value:
            payload = empty_content()
        elif isinstance(value, str):
            try:
                payload = parse_content(json.loads(value))
            except json.JSONDecodeError:
                payload = parse_content(None, value)
        else:
            payload = parse_content(value)

        return json.dumps(payload, ensure_ascii=False)

    def value_from_datadict(self, data, files, name):
        raw = data.get(name, '')

        if not raw:
            return empty_content()

        try:
            decoded = json.loads(raw)
        except json.JSONDecodeError:
            return empty_content()

        return parse_content(decoded)


class InfoContentField(forms.JSONField):
    widget = InfoContentWidget

    def prepare_value(self, value):
        if value is None:
            return empty_content()

        return parse_content(value)

    def bound_data(self, data, initial):
        if data is None:
            return initial

        if isinstance(data, (dict, list)):
            return parse_content(data)

        return super().bound_data(data, initial)


class MultipleFileInput(forms.FileInput):
    allow_multiple_selected = True


class MultipleFileField(forms.FileField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('widget', MultipleFileInput())
        super().__init__(*args, **kwargs)

    def clean(self, data, initial=None):
        if not data:
            return []

        if isinstance(data, (list, tuple)):
            return [
                super(MultipleFileField, self).clean(item, initial)
                for item in data
                if item
            ]

        return [super(MultipleFileField, self).clean(data, initial)]
