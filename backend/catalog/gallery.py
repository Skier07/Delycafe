from django.db.models import Max

from catalog.models import Product, ProductGalleryImage


def sync_product_cover_image(product: Product) -> None:
    first_image = product.gallery_images.order_by('sort_order', 'id').first()

    if first_image is None:
        if product.image:
            product.image = None
            product.save(update_fields=['image', 'updated_at'])
        return

    if product.image != first_image.image:
        product.image = first_image.image
        product.save(update_fields=['image', 'updated_at'])


def append_gallery_images(product: Product, files) -> int:
    if not files:
        return 0

    max_sort = (
        product.gallery_images.aggregate(max_sort=Max('sort_order'))['max_sort']
        or 0
    )
    created = 0

    for index, uploaded_file in enumerate(files):
        ProductGalleryImage.objects.create(
            product=product,
            image=uploaded_file,
            sort_order=max_sort + (index + 1) * 10,
        )
        created += 1

    sync_product_cover_image(product)

    return created
