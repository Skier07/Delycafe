from rest_framework import serializers

from catalog.models import AppPageContent, ContentPost
from catalog.page_content import resolved_lines
from catalog.placeholders import (
    promotion_placeholder_values,
    substitute_content_lines,
    substitute_placeholders,
)


class ContentPostSerializer(serializers.ModelSerializer):
    cover_image = serializers.SerializerMethodField()
    body_lines = serializers.SerializerMethodField()
    plain_text = serializers.SerializerMethodField()

    class Meta:
        model = ContentPost
        fields = (
            'id',
            'post_type',
            'title',
            'cover_image',
            'body_lines',
            'plain_text',
            'sort_order',
            'published_at',
            'updated_at',
        )

    def get_cover_image(self, obj):
        if not obj.cover_image:
            return ''

        request = self.context.get('request')
        url = obj.cover_image.url

        if request is not None:
            return request.build_absolute_uri(url)

        return url

    def get_body_lines(self, obj):
        lines = resolved_lines(obj.body)
        values = promotion_placeholder_values()
        substituted = substitute_content_lines(lines, values)

        request = self.context.get('request')
        for line in substituted:
            image_url = line.get('image_url') or ''
            if image_url.startswith('/') and request is not None:
                line['image_url'] = request.build_absolute_uri(image_url)

        return substituted

    def get_plain_text(self, obj):
        return substitute_placeholders(
            obj.plain_text or '',
            promotion_placeholder_values(),
        )


class AppPageContentSerializer(serializers.ModelSerializer):
    body_lines = serializers.SerializerMethodField()
    plain_text = serializers.SerializerMethodField()
    placeholders = serializers.SerializerMethodField()

    class Meta:
        model = AppPageContent
        fields = (
            'key',
            'title',
            'body_lines',
            'plain_text',
            'placeholders',
            'updated_at',
        )

    def get_body_lines(self, obj):
        return substitute_content_lines(
            resolved_lines(obj.body),
            promotion_placeholder_values(),
        )

    def get_plain_text(self, obj):
        return substitute_placeholders(
            obj.plain_text or '',
            promotion_placeholder_values(),
        )

    def get_placeholders(self, obj):
        return promotion_placeholder_values()
