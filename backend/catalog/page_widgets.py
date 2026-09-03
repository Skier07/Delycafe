import json

from django import forms
from django.forms.widgets import Widget

from catalog.page_content import empty_content, parse_content


class PageContentWidget(Widget):
    template_name = 'admin/catalog/page_content_widget.html'

    class Media:
        css = {
            'all': ('catalog/admin/page_content_editor.css',),
        }
        js = ('catalog/admin/page_content_editor.js',)

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


class PageContentField(forms.JSONField):
    widget = PageContentWidget

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
