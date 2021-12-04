import logging
from django.shortcuts import render
from images.models import FeaturedImage
from django.conf import settings

logger = logging.getLogger(__name__)


def home(request):
    try:
        image = FeaturedImage.objects.latest('uploaded')
        logger.info('STATIC_ROOT=%s', settings.STATIC_ROOT)
    except FeaturedImage.DoesNotExist:
        logger.warning('no images yet')
        image = None

    return render(request, 'images/home.html', {'image': image})
