from django.shortcuts import render, get_object_or_404, redirect
from django.contrib import messages
from django.db.models import Count, Avg, Max, Min, Sum, Q
from .models import Product, Category, SKU, Stock, Order, OrderItem
from .forms import ProductForm, SearchForm


# ─────────────────────────────────────────────────────────────
# 1. LISTE + RECHERCHE PAR MOT-CLÉ (R1 & R7)
# ─────────────────────────────────────────────────────────────
def product_list(request):
    """Liste tous les produits, triés alphabétiquement + recherche mot-clé"""
    form = SearchForm(request.GET or None)
    products = Product.objects.select_related('category').order_by('name')

    keyword = request.GET.get('keyword', '')
    category_id = request.GET.get('category', '')
    min_price = request.GET.get('min_price', '')
    max_price = request.GET.get('max_price', '')

    # Recherche par mot-clé (name ou description)
    if keyword:
        products = products.filter(
            Q(name__icontains=keyword) | Q(description__icontains=keyword)
        )

    # Filtre par catégorie (critère par identifiant)
    if category_id:
        products = products.filter(category_id=category_id)

    # Filtre numérique par prix
    if min_price:
        products = products.filter(price__gte=min_price)
    if max_price:
        products = products.filter(price__lte=max_price)

    return render(request, 'products/list.html', {
        'products': products,
        'form': form,
        'total': products.count(),
        'keyword': keyword,
    })


# ─────────────────────────────────────────────────────────────
# 2. DÉTAIL d'un produit avec données associées (SKU, Stock)
# ─────────────────────────────────────────────────────────────
def product_detail(request, pk):
    """Affiche un produit avec ses SKU et niveaux de stock"""
    product = get_object_or_404(Product, pk=pk)
    skus = SKU.objects.filter(product=product).select_related('size', 'color').prefetch_related('stock_set__location')

    total_stock = Stock.objects.filter(sku__product=product).aggregate(total=Sum('quantity'))['total'] or 0

    return render(request, 'products/detail.html', {
        'product': product,
        'skus': skus,
        'total_stock': total_stock,
    })


# ─────────────────────────────────────────────────────────────
# 3. AJOUTER un produit
# ─────────────────────────────────────────────────────────────
def product_create(request):
    """Formulaire d'ajout d'un nouveau produit"""
    if request.method == 'POST':
        form = ProductForm(request.POST)
        if form.is_valid():
            product = form.save()
            messages.success(request, f'✅ Produit "{product.name}" ajouté avec succès !')
            return redirect('product_detail', pk=product.pk)
    else:
        form = ProductForm()

    return render(request, 'products/form.html', {
        'form': form,
        'title': 'Ajouter un produit',
        'btn_label': 'Ajouter',
    })


# ─────────────────────────────────────────────────────────────
# 4. MODIFIER un produit
# ─────────────────────────────────────────────────────────────
def product_update(request, pk):
    """Formulaire de modification d'un produit existant"""
    product = get_object_or_404(Product, pk=pk)

    if request.method == 'POST':
        form = ProductForm(request.POST, instance=product)
        if form.is_valid():
            form.save()
            messages.success(request, f'✅ Produit "{product.name}" modifié avec succès !')
            return redirect('product_detail', pk=product.pk)
    else:
        form = ProductForm(instance=product)

    return render(request, 'products/form.html', {
        'form': form,
        'product': product,
        'title': f'Modifier — {product.name}',
        'btn_label': 'Enregistrer',
    })


# ─────────────────────────────────────────────────────────────
# 5. SUPPRIMER un produit
# ─────────────────────────────────────────────────────────────
def product_delete(request, pk):
    """Suppression d'un produit avec confirmation"""
    product = get_object_or_404(Product, pk=pk)

    if request.method == 'POST':
        name = product.name
        product.delete()
        messages.success(request, f'🗑️ Produit "{name}" supprimé.')
        return redirect('product_list')

    return render(request, 'products/confirm_delete.html', {'product': product})


# ─────────────────────────────────────────────────────────────
# 6. STATISTIQUES & CLASSEMENT
# ─────────────────────────────────────────────────────────────
def stats(request):
    """Classements et statistiques globales"""

    # Nb produits par catégorie (trié décroissant)
    by_category = Category.objects.annotate(
        nb_products=Count('products')
    ).filter(nb_products__gt=0).order_by('-nb_products')

    # Prix moyen, max, min global
    global_stats = Product.objects.aggregate(
        avg_price=Avg('price'),
        max_price=Max('price'),
        min_price=Min('price'),
        total_products=Count('id'),
    )

    # Top 5 produits les plus chers
    top_products = Product.objects.select_related('category').order_by('-price')[:5]

    # Catégories avec somme des prix > 200
    rich_categories = Category.objects.annotate(
        sum_price=Sum('products__price')
    ).filter(sum_price__gt=200).order_by('-sum_price')

    # Produits au-dessus de la moyenne (R11)
    avg_price = Product.objects.aggregate(avg=Avg('price'))['avg'] or 0
    above_avg = Product.objects.filter(price__gt=avg_price).count()

    return render(request, 'products/stats.html', {
        'by_category': by_category,
        'global_stats': global_stats,
        'top_products': top_products,
        'rich_categories': rich_categories,
        'avg_price': avg_price,
        'above_avg': above_avg,
    })
