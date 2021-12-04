from django.test import TestCase, Client, override_settings
from images.models import FeaturedImage


class TestHomeView(TestCase):
    def setUp(self):
        self.client = Client()

    def test_home_no_images(self):
        response = self.client.get('/')
        self.assertIsNone(response.context['image'])
        self.assertContains(response, 'No images yet, upload one', status_code=200)

    @override_settings(AWS_STORAGE_BUCKET_NAME='bucket.name')
    def test_home_images(self):
        image1 = FeaturedImage.objects.create(
            name='one image', tagline='one tagline',
            img='image1.png'
        )
        image2 = FeaturedImage.objects.create(
            name='recent image', tagline='recent tagline',
            img='image2.png'
        )

        response = self.client.get('/')
        self.assertEqual(response.context['image'], image2)
        self.assertContains(
            response,
            'background: url(https://s3.amazonaws.com/bucket.name/devops-tech-assignment/image2.png',
            status_code=200
        )
        self.assertContains(response, '<h1>recent image</h1>', html=True)
        self.assertContains(response, '<p>recent tagline</p>', html=True)
