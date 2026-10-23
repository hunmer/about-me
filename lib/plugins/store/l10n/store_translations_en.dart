const Map<String, String> storeTranslationsEn = {
  // Basic info
  'store_name': 'Store',

  // Confirmations
  'store_confirmUse': 'Use Confirmation',
  'store_confirmUseMessage': 'Are you sure you want to use @productName?',
  'store_confirmArchiveTitle': 'Confirm Archive',
  'store_confirmArchiveMessage':
      'Are you sure you want to archive this product? Archived products can be viewed in the filter.',
  'store_confirmDeleteTitle': 'Confirm Delete',
  'store_confirmDeleteMessage':
      'Are you sure you want to delete this product? This action cannot be undone.',
  'store_redeemConfirmation': 'Are you sure you want to redeem this item?',
  'store_redeemConfirmationMessage':
      'Are you sure you want to redeem %s? It will cost %d points',
  'store_insufficientPoints': 'Insufficient points',

  // Points settings
  'store_storeSettings': 'Store Settings',
  'store_enablePointsNotification': 'Points Change Notification',
  'store_enablePointsNotificationDescription':
      'Show notification when points change',
  'store_enableExpiringReminder': 'Expiry Reminder',
  'store_enableExpiringReminderDescription':
      'Send reminder when items are about to expire',
  'store_addPointsDialogTitle': 'Add Points',
  'store_pointsAmountLabel': 'Points Amount',
  'store_reasonLabel': 'Reason',
  'store_pointsAdjustmentDefaultReason': 'Points adjustment',
  'store_myPoints': 'Points',
  'store_points': 'Points',
  'store_pointsAdded': 'Points added',
  'store_earnPointsTip': 'Complete activities in the app to earn points',

  // Quantity stats
  'store_productQuantity': 'Products',
  'store_itemQuantity': 'Items',
  'store_expiringIn7Days': 'Expiring',

  // Clear operations

  // Filter related
  'store_categoryLabel': 'Category',
  'store_categoryHint': 'Select category',
  'store_categoryFood': 'Food',
  'store_categoryClothes': 'Clothing',
  'store_categoryTech': 'Tech',
  'store_categoryFurniture': 'Home',
  'store_categoryOther': 'Other',
  'store_productRemoved': 'Removed product',
  'store_categoryUncategorized': 'Uncategorized',
  'store_itemStatus': 'Item Status',
  'store_all': 'All',
  'store_usable': 'Usable',
  'store_expired': 'Expired',
  'store_priceRange': 'Price Range',
  'store_exchangeStatus': 'Exchange Status',
  'store_exchanging': 'Ongoing',
  'store_notStarted': 'Upcoming',
  'store_exchangeEnded': 'Ended',
  'store_stockStatus': 'Stock',
  'store_inStock': 'In Stock',
  'store_minPrice': 'Min points',
  'store_maxPrice': 'Max points',
  'store_dateRange': 'Date Range',

  // Sort related
  'store_sortByStock': 'By Stock',
  'store_sortByPrice': 'By Price',
  'store_defaultSort': 'Default Sort',
  'store_sortByExpiryDate': 'Sort by Expiry Date',

  // Product related
  'store_addProductTitle': 'Add Product',
  'store_productNameLabel': 'Product Name',
  'store_productNameRequired': 'Please enter product name',
  'store_priceLabel': 'Price (points)',
  'store_priceInvalid': 'Please enter a valid number',
  'store_stockLabel': 'Stock Quantity',
  'store_descriptionLabel': 'Product Description',
  'store_noProducts': 'No Products',
  'store_productList': 'Product List',

  // Success/failure operations
  'store_useSuccess': 'Used successfully',
  'store_useSuccessMessage': 'Used successfully',
  'store_itemExpired': 'Item expired',
  'store_itemExpiredMessage': 'Item has expired',
  'store_redeemSuccess': 'Redeemed successfully',
  'store_redeemFailed': 'Redeem failed, please check points or stock',

  // Archive related

  // Item related
  'store_noItems': 'No items',
  'store_myItems': 'My Items',
  'store_itemDetailsTitle': 'Item Details',
  'store_useConfirmationTitle': 'Use Confirmation',
  'store_useConfirmationMessage': 'Are you sure you want to use %s?',
  'store_purchaseDateLabel': 'Purchase Date',
  'store_expiryDateLabel': 'Expiry Date',
  'store_purchasePriceLabel': 'Purchase Price',
  'store_remainingQuantityLabel': 'Remaining Quantity',
  'store_viewProductInfo': 'View Product Info',
  'store_productNotFound': 'Product not found or deleted',

  // Records related
  'store_noRecords': 'No records',
  'store_pointsHistory': 'Points History',
  'store_pointsHistoryEntry': '{value} points ({type})',

  // Buttons
  'store_deleteButton': 'Delete',
  'store_archiveButton': 'Archive',
  'store_saveButton': 'Save',
  'store_cancel': 'Cancel',
  'store_add': 'Add',

  // Utility methods
  'store_labelColon': '@label: ',

  // Search placeholders
  'store_searchItemPlaceholder': 'Search item name or description',
  'store_searchProductPlaceholder': 'Search product name or description',

  // Home Widget Strings
  'store_widgetName': 'Store',
  'store_widgetDescription': 'Quick access to store',
  'store_overviewName': 'Store Overview',
  'store_overviewDescription': 'Display points and products statistics',

  // Selector Widget Strings
  'store_productSelectorName': 'Select Product',
  'store_productSelectorDesc': 'Select a product to view redeemed items',
  'store_selectProduct': 'Select Product',
  'store_productQuickAccess': 'Product Quick Access',
  'store_productQuickAccessDesc': 'Quick access to specific product items list',
  'store_outOfStock': 'Out of Stock',
  'store_userItemSelectorName': 'Select Item',
  'store_userItemSelectorDesc': 'Select an item to view details',
  'store_selectUserItem': 'Select Item',
  'store_userItemQuickAccess': 'Item Quick Access',
  'store_userItemQuickAccessDesc': 'Quick access to item details',
  'store_times': 'times',
  'store_expireIn': 'Expires in',
  'store_days': 'days',

  // Points history search and filter
  'store_searchReason': 'Search reason',
  'store_type': 'Type',
  'store_selectDateRange': 'Select date range',
  'store_sort': 'Sort',
  'store_newestFirst': 'Newest first',
  'store_oldestFirst': 'Oldest first',

  // Card & empty states (minimal sketch redesign)
  'store_use': 'Use',
  'store_redeem': 'Redeem',
  'store_editProduct': 'Edit product',
  'store_expiringSoon': 'Expiring soon',
  'store_daysLeft': '@days days left',
  'store_remainingTimes': '@count uses left',
  'store_validUntilDate': 'Valid until @date',
  'store_pricePoints': '@price pts',
  'store_redeemConfirmMessage': 'Redeem @name? It costs @price points.',
  'store_emptyItemsHint': 'Redeem items in the product list',
  'store_noItemsForFilter': 'No items match the filters',
  'store_searchItemsHint': 'Type keywords to search items',
  'store_noSearchResults': 'No matching items',
  'store_tryOtherKeywords': 'Try different keywords',
  'store_noMatchingProducts': 'No matching products',

  // Reward events & daily target settings
  'store_pointsAwardSection': 'Points Rewards',
  'store_eventSwitchesEntry': 'Reward Event Switches',
  'store_eventSwitchesEntryDesc': 'View all supported events and toggle rewards',
  'store_eventSwitchesTitle': 'Reward Events',
  'store_eventSwitchesSubtitle': 'Turn on events that award points; off means no rewards',
  'store_noEventsEnabled':
      'No events enabled\nEnable them in the Reward Events page',
  'store_dailyTargetLabel': 'Daily Target',
  'store_dailyTargetDesc': 'Set your daily points goal',

  // Daily score stats
  'store_dailyScoreTitle': "Today's Score",
  'store_otherCategory': 'Other',
  'store_prevDay': 'Previous Day',
  'store_nextDay': 'Next Day',
    'store_pluginNotAvailable': 'Plugin not available',
};
