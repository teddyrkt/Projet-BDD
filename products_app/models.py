from django.db import models


class Category(models.Model):
    name = models.CharField(max_length=50)
    parent = models.ForeignKey(
        'self', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='subcategories'
    )

    class Meta:
        db_table = 'categories'
        verbose_name_plural = 'categories'
        ordering = ['name']

    def __str__(self):
        return self.name


class Product(models.Model):
    category = models.ForeignKey(
        Category, null=True, blank=True,
        on_delete=models.RESTRICT, related_name='products'
    )
    name = models.CharField(max_length=50)
    description = models.TextField(null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    created_at = models.DateField(auto_now_add=True)

    class Meta:
        db_table = 'products'
        ordering = ['name']

    def __str__(self):
        return self.name


class Color(models.Model):
    name = models.CharField(max_length=50, unique=True)

    class Meta:
        db_table = 'colors'

    def __str__(self):
        return self.name


class Size(models.Model):
    name = models.CharField(max_length=4, unique=True)

    class Meta:
        db_table = 'sizes'

    def __str__(self):
        return self.name


class SKU(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='skus')
    size = models.ForeignKey(Size, on_delete=models.RESTRICT)
    color = models.ForeignKey(Color, on_delete=models.RESTRICT)

    class Meta:
        db_table = 'sku'
        unique_together = ('product', 'size', 'color')

    def __str__(self):
        return f"{self.product.name} — {self.size.name} / {self.color.name}"


class Location(models.Model):
    TYPE_CHOICES = [('STORE', 'Store'), ('WAREHOUSE', 'Warehouse'), ('OUTLET', 'Outlet')]
    name = models.CharField(max_length=50)
    type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    address = models.TextField(null=True, blank=True)

    class Meta:
        db_table = 'locations'

    def __str__(self):
        return f"{self.name} ({self.type})"


class Stock(models.Model):
    location = models.ForeignKey(Location, on_delete=models.CASCADE)
    sku = models.ForeignKey(SKU, on_delete=models.CASCADE)
    quantity = models.IntegerField(default=0)

    class Meta:
        db_table = 'stock'
        unique_together = ('location', 'sku')

    def __str__(self):
        return f"{self.sku} @ {self.location.name} : {self.quantity}"


class Customer(models.Model):
    firstname = models.CharField(max_length=50)
    lastname = models.CharField(max_length=50)
    email = models.EmailField(max_length=255, unique=True)

    class Meta:
        db_table = 'customers'

    def __str__(self):
        return f"{self.firstname} {self.lastname}"


class Order(models.Model):
    STATUS_CHOICES = [('PENDING', 'Pending'), ('PAID', 'Paid'), ('CANCELLED', 'Cancelled')]
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE)
    location = models.ForeignKey(Location, on_delete=models.RESTRICT)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    created_at = models.DateField(auto_now_add=True)

    class Meta:
        db_table = 'orders'

    def __str__(self):
        return f"Commande #{self.id} — {self.customer}"


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    sku = models.ForeignKey(SKU, on_delete=models.RESTRICT)
    quantity = models.IntegerField(default=0)
    price = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        db_table = 'order_items'
        unique_together = ('order', 'sku')
