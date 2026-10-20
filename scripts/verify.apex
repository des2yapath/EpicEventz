List<EevEventExplorerController.EventCard> results = EevEventExplorerController.searchEvents(null, null, null, null, null);
System.debug('=== VERIFY 1: All visible on-sale events count: ' + results.size());
for (EevEventExplorerController.EventCard card : results) {
    System.debug('=== Found Event: ' + card.name + ' | Venue: ' + card.venueName + ' | City: ' + card.city + ' | PriceFrom: ' + card.priceFrom);
}

List<EevEventExplorerController.EventCard> searchResults = EevEventExplorerController.searchEvents('architects', null, null, null, null);
System.debug('=== VERIFY 2: Search for "architects" count: ' + searchResults.size());
for (EevEventExplorerController.EventCard card : searchResults) {
    System.debug('=== Found Search Event: ' + card.name);
}

if (!results.isEmpty()) {
    EevEventExplorerController.EventDetail detail = EevEventExplorerController.getEventDetail(results[0].id);
    System.debug('=== VERIFY 3: EventDetail: ' + detail.header.name + ' with ' + detail.tiers.size() + ' tiers');
    for (EevEventExplorerController.TierRow t : detail.tiers) {
        System.debug('=== Tier: ' + t.name + ', Price: ' + t.price + ', Available: ' + t.available + ', IsSellable: ' + t.isSellable);
    }
}

