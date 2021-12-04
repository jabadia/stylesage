from django.contrib import admin
from django.utils.safestring import mark_safe

from images.models import FeaturedImage


@admin.register(FeaturedImage)
class FeaturedImageAdmin(admin.ModelAdmin):
    list_display = ('thumbnail', 'name', 'tagline', 'uploaded')
    ordering = ('-uploaded',)

    def thumbnail(self, obj):
        if obj.img:
            return mark_safe('<img src="%s" style="height: 50px; width: auto">' % (obj.img.url))
        else:
            "no image"
