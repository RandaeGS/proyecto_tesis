from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
import datetime

from ..models import (
    InventorySnapshot, ProductCategory, InventoryItem, InventoryReport,
    ProductRecommendation, AnalyticsReport, CategoryConsumptionTotal,
    ConsumptionDataPoint
)
from .serializers import (
    InventorySnapshotSerializer, ProductCategorySerializer, InventoryItemSerializer,
    InventoryReportSerializer, ProductRecommendationSerializer, AnalyticsReportSerializer,
    GenerateInventoryReportSerializer, GenerateAnalyticsReportSerializer, ConsumptionDataPointSerializer
)


class ProductCategoryViewSet(viewsets.ModelViewSet):
    """
    API endpoint for Product Categories
    """
    queryset = ProductCategory.objects.all()
    serializer_class = ProductCategorySerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'ideal_count', 'emergency_priority', 'created_at']

    @action(detail=False, methods=['GET'])
    def with_ideal_counts(self, request):
        """
        Get all categories with their ideal counts for inventory management
        """
        categories = self.get_queryset()

        # Format as a dictionary for easier use in Flutter
        ideal_counts = {}
        for category in categories:
            ideal_counts[category.name] = category.ideal_count

        return Response(ideal_counts)

    @action(detail=False, methods=['POST'])
    def update_ideal_counts(self, request):
        """
        Update ideal counts for multiple categories at once
        """
        # Expected format: {category_name: ideal_count, ...}
        counts_data = request.data

        updated = []
        created = []

        for name, ideal_count in counts_data.items():
            try:
                # Try to update existing category
                category = ProductCategory.objects.get(name=name)
                category.ideal_count = ideal_count
                category.save()
                updated.append(name)
            except ProductCategory.DoesNotExist:
                # Create new category
                ProductCategory.objects.create(
                    name=name,
                    ideal_count=ideal_count
                )
                created.append(name)

        return Response({
            'updated': updated,
            'created': created
        })


class InventorySnapshotViewSet(viewsets.ModelViewSet):
    """
    API endpoint for Inventory Snapshots
    """
    serializer_class = InventorySnapshotSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['center']
    ordering_fields = ['created_at', 'name']
    ordering = ['-created_at']

    def get_queryset(self):
        """Filter snapshots by center if user is not superuser"""
        user = self.request.user
        if not user.is_superuser:
            # Get centers the user belongs to
            centers = user.centers.all()
            return InventorySnapshot.objects.filter(center__in=centers)
        return InventorySnapshot.objects.all()

    def perform_create(self, serializer):
        """Set created_by to current user"""
        serializer.save(created_by=self.request.user)

    @action(detail=False, methods=['GET'])
    def by_center(self, request):
        """
        Get snapshots for a specific center
        """
        center_id = request.query_params.get('center_id')
        if not center_id:
            return Response(
                {'error': 'center_id parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        snapshots = self.get_queryset().filter(center_id=center_id)
        serializer = self.get_serializer(snapshots, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['GET'])
    def product_counts(self, request, pk=None):
        """
        Get product counts for a specific snapshot
        """
        snapshot = self.get_object()
        items = snapshot.items.all()

        # Format as a dictionary (category_name: count)
        counts = {}
        for item in items:
            counts[item.category.name] = item.count

        return Response(counts)


class InventoryReportViewSet(viewsets.ModelViewSet):
    """
    API endpoint for Inventory Reports
    """
    serializer_class = InventoryReportSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['center', 'is_emergency']
    ordering_fields = ['created_at', 'name']
    ordering = ['-created_at']

    def get_queryset(self):
        """Filter reports by center if user is not superuser"""
        user = self.request.user
        if not user.is_superuser:
            # Get centers the user belongs to
            centers = user.centers.all()
            return InventoryReport.objects.filter(center__in=centers)
        return InventoryReport.objects.all()

    def perform_create(self, serializer):
        """Set created_by to current user"""
        serializer.save(created_by=self.request.user)

    @action(detail=False, methods=['GET'])
    def by_center(self, request):
        """
        Get reports for a specific center
        """
        center_id = request.query_params.get('center_id')
        if not center_id:
            return Response(
                {'error': 'center_id parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        reports = self.get_queryset().filter(center_id=center_id)
        serializer = self.get_serializer(reports, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['GET'])
    def latest(self, request):
        """
        Get the latest report for a center
        """
        center_id = request.query_params.get('center_id')
        if not center_id:
            return Response(
                {'error': 'center_id parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        report = self.get_queryset().filter(center_id=center_id).first()
        if not report:
            return Response(
                {'error': 'No reports found for this center'},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = self.get_serializer(report)
        return Response(serializer.data)

    @action(detail=False, methods=['GET'])
    def priority_products(self, request):
        """
        Get priority products from the latest report
        """
        center_id = request.query_params.get('center_id')
        if not center_id:
            return Response(
                {'error': 'center_id parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        report = self.get_queryset().filter(center_id=center_id).first()
        if not report:
            return Response(
                {'error': 'No reports found for this center'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Get high priority products (priority > 3)
        high_priority = report.recommendations.filter(priority__gt=3)

        # Format as a dictionary (category_name: recommendation)
        priority_products = {}
        for rec in high_priority:
            priority_products[rec.category.name] = ProductRecommendationSerializer(rec).data

        return Response(priority_products)

    @action(detail=False, methods=['GET'])
    def by_category(self, request):
        """
        Get product recommendations by category
        """
        center_id = request.query_params.get('center_id')
        category = request.query_params.get('category')

        if not center_id or not category:
            return Response(
                {'error': 'Both center_id and category parameters are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get latest report
        report = self.get_queryset().filter(center_id=center_id).first()
        if not report:
            return Response(
                {'error': 'No reports found for this center'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Find recommendation for the category
        try:
            category_obj = ProductCategory.objects.get(name=category)
            recommendation = report.recommendations.get(category=category_obj)
            serializer = ProductRecommendationSerializer(recommendation)
            return Response([serializer.data])  # Return as a list for compatibility
        except (ProductCategory.DoesNotExist, ProductRecommendation.DoesNotExist):
            return Response([])  # Empty list for compatibility

    @action(detail=False, methods=['POST'])
    def generate(self, request):
        """
        Generate a new inventory report based on a snapshot
        """
        serializer = GenerateInventoryReportSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # Get validated data
        snapshot_id = serializer.validated_data['snapshot_id']
        is_emergency = serializer.validated_data.get('is_emergency', False)
        custom_ideal_counts = serializer.validated_data.get('custom_ideal_counts', {})

        try:
            # Get the snapshot
            snapshot = InventorySnapshot.objects.get(id=snapshot_id)

            # Create a name for the report
            now = datetime.datetime.now()
            report_name = f"{'Informe de Emergencia' if is_emergency else 'Informe de Reposicion'} {now.day}/{now.month}/{now.year}"

            # Create the report
            report = InventoryReport.objects.create(
                name=report_name,
                center=snapshot.center,
                created_by=request.user,
                is_emergency=is_emergency,
                source_snapshot=snapshot
            )

            # Get all product categories
            categories = ProductCategory.objects.all()

            # Create recommendations for each category
            for category in categories:
                # Get current count from snapshot
                try:
                    inventory_item = InventoryItem.objects.get(
                        snapshot=snapshot,
                        category=category
                    )
                    current_count = inventory_item.count
                except InventoryItem.DoesNotExist:
                    current_count = 0

                # Get ideal count (custom or default)
                ideal_count = custom_ideal_counts.get(
                    category.name,
                    category.ideal_count
                )

                # Calculate priority based on percentage missing
                if is_emergency:
                    # In emergency, use predefined emergency_priority
                    priority = category.emergency_priority
                else:
                    # Calculate based on percentage missing
                    if ideal_count <= 0:
                        percentage_missing = 0
                    else:
                        percentage_missing = ((ideal_count - current_count) / ideal_count) * 100

                    if percentage_missing <= 10:
                        priority = 1  # Very Low
                    elif percentage_missing <= 30:
                        priority = 2  # Low
                    elif percentage_missing <= 50:
                        priority = 3  # Medium
                    elif percentage_missing <= 75:
                        priority = 4  # High
                    else:
                        priority = 5  # Very High

                # Create note based on stock level
                note = ''
                if current_count <= 0:
                    note = 'URGENTE: No hay existencias'
                elif current_count < ideal_count * 0.25:
                    note = 'Nivel critico de existencias'
                elif current_count < ideal_count * 0.5:
                    note = 'Nivel bajo de existencias'

                # Create recommendation
                ProductRecommendation.objects.create(
                    report=report,
                    category=category,
                    current_count=current_count,
                    ideal_count=ideal_count,
                    priority=priority,
                    note=note
                )

            serializer = InventoryReportSerializer(report)
            return Response(serializer.data)

        except InventorySnapshot.DoesNotExist:
            return Response(
                {'error': 'Snapshot not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class AnalyticsReportViewSet(viewsets.ModelViewSet):
    """
    API endpoint for Analytics Reports
    """
    serializer_class = AnalyticsReportSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['center', 'period_type']
    ordering_fields = ['created_at', 'name']
    ordering = ['-created_at']

    def get_queryset(self):
        """Filter reports by center if user is not superuser"""
        user = self.request.user
        if not user.is_superuser:
            # Get centers the user belongs to
            centers = user.centers.all()
            return AnalyticsReport.objects.filter(center__in=centers)
        return AnalyticsReport.objects.all()

    def perform_create(self, serializer):
        """Set created_by to current user"""
        serializer.save(created_by=self.request.user)

    @action(detail=False, methods=['GET'])
    def by_center(self, request):
        """
        Get analytics reports for a specific center
        """
        center_id = request.query_params.get('center_id')
        if not center_id:
            return Response(
                {'error': 'center_id parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        reports = self.get_queryset().filter(center_id=center_id)
        serializer = self.get_serializer(reports, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['GET'])
    def consumption_data(self, request, pk=None):
        """
        Get detailed consumption data for a specific report
        """
        report = self.get_object()

        # Group data by category
        data = {}
        for category in report.get_analyzed_categories():
            # Get consumption data points
            data_points = ConsumptionDataPoint.objects.filter(
                report=report,
                category=category
            ).order_by('date')

            # Serialize data points
            data[category.name] = ConsumptionDataPointSerializer(data_points, many=True).data

        return Response(data)

    @action(detail=False, methods=['POST'])
    def generate(self, request):
        """
        Generate a new analytics report
        """
        serializer = GenerateAnalyticsReportSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # Get validated data
        start_snapshot_id = serializer.validated_data['start_snapshot_id']
        end_snapshot_id = serializer.validated_data['end_snapshot_id']
        period_type = serializer.validated_data.get('period_type', 'weekly')
        report_name = serializer.validated_data.get('report_name', '')
        selected_categories = serializer.validated_data.get('selected_categories', [])

        try:
            # Get snapshots
            start_snapshot = InventorySnapshot.objects.get(id=start_snapshot_id)
            end_snapshot = InventorySnapshot.objects.get(id=end_snapshot_id)

            # Check dates
            start_date = start_snapshot.created_at
            end_date = end_snapshot.created_at

            if start_date > end_date:
                return Response(
                    {'error': 'Start date must be earlier than end date'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get or create report name
            if not report_name:
                now = datetime.datetime.now()
                report_name = f"{'Analisis Semanal' if period_type == 'weekly' else 'Analisis Mensual'} {now.day}/{now.month}/{now.year}"

            # Create report
            report = AnalyticsReport.objects.create(
                name=report_name,
                center=start_snapshot.center,
                created_by=request.user,
                period_type=period_type,
                start_date=start_date,
                end_date=end_date,
                start_snapshot=start_snapshot,
                end_snapshot=end_snapshot
            )

            # Get categories to analyze
            categories_to_analyze = []
            if selected_categories:
                # Use selected categories
                for cat_name in selected_categories:
                    try:
                        category = ProductCategory.objects.get(name=cat_name)
                        categories_to_analyze.append(category)
                    except ProductCategory.DoesNotExist:
                        # Create category if it doesn't exist
                        category = ProductCategory.objects.create(name=cat_name)
                        categories_to_analyze.append(category)
            else:
                # Use all categories from both snapshots
                start_categories = set(item.category for item in start_snapshot.items.all())
                end_categories = set(item.category for item in end_snapshot.items.all())
                categories_to_analyze = list(start_categories.union(end_categories))

            # Calculate consumption for each category
            days = (end_date - start_date).days + 1
            import random  # For distributing consumption data

            for category in categories_to_analyze:
                # Get counts from both snapshots
                try:
                    start_count = InventoryItem.objects.get(
                        snapshot=start_snapshot,
                        category=category
                    ).count
                except InventoryItem.DoesNotExist:
                    start_count = 0

                try:
                    end_count = InventoryItem.objects.get(
                        snapshot=end_snapshot,
                        category=category
                    ).count
                except InventoryItem.DoesNotExist:
                    end_count = 0

                # Calculate consumption (assume consumption = reduction in inventory)
                consumption_value = max(0, start_count - end_count)

                # Create total consumption record
                CategoryConsumptionTotal.objects.create(
                    report=report,
                    category=category,
                    count=consumption_value
                )

                # Skip generating data points if no consumption
                if consumption_value <= 0:
                    continue

                # Generate consumption data points based on period type
                if period_type == 'weekly':
                    # For weekly analysis, generate daily data points with random distribution
                    remaining = consumption_value

                    for i in range(days):
                        day_date = start_date + datetime.timedelta(days=i)

                        # Calculate consumption for this day
                        if i == days - 1:
                            # Last day gets remaining consumption
                            daily_consumption = remaining
                        else:
                            # Random consumption that doesn't exceed remaining
                            max_daily = max(1, int(remaining / (days - i)))
                            daily_consumption = random.randint(0, max_daily)

                        # Update remaining consumption
                        remaining -= daily_consumption

                        # Create data point if there was consumption
                        if daily_consumption > 0:
                            ConsumptionDataPoint.objects.create(
                                report=report,
                                category=category,
                                date=day_date,
                                count=daily_consumption
                            )

                elif period_type == 'monthly':
                    # For monthly analysis, group by weeks
                    weeks = (days // 7) + (1 if days % 7 > 0 else 0)
                    remaining = consumption_value

                    for i in range(weeks):
                        week_start = start_date + datetime.timedelta(days=i * 7)

                        # Calculate consumption for this week
                        if i == weeks - 1:
                            # Last week gets remaining consumption
                            weekly_consumption = remaining
                        else:
                            # Random consumption that doesn't exceed remaining
                            max_weekly = max(1, int(remaining / (weeks - i)))
                            weekly_consumption = random.randint(0, max_weekly)

                        # Update remaining consumption
                        remaining -= weekly_consumption

                        # Create data point if there was consumption
                        if weekly_consumption > 0:
                            ConsumptionDataPoint.objects.create(
                                report=report,
                                category=category,
                                date=week_start,
                                count=weekly_consumption,
                                note=f'Semana {i + 1}'
                            )

            serializer = AnalyticsReportSerializer(report)
            return Response(serializer.data)

        except InventorySnapshot.DoesNotExist:
            return Response(
                {'error': 'One or both snapshots not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
