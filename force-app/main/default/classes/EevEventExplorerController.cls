/**
 * @description Thin, read-only controller for the eventExplorer Lightning Web Component.
 * Enforces USER_MODE security, supports SOSL full-text search combined with SOQL attribute filtering,
 * and aggregates tier pricing and availability.
 * Architectural note: SOSL cannot filter on parent (Venue__r) relationship fields. Therefore,
 * text search resolves matching Event IDs via SOSL, which are then passed as an ID-filter into
 * a SOQL query that applies category, city, date predicates, and sort order.
 * @author EpicEventz Development Team
 */
public with sharing class EevEventExplorerController {

    /**
     * @description Search and discover public, on-sale events with active sales windows.
     */
    @AuraEnabled(cacheable=true)
    public static List<EventCard> searchEvents(String searchTerm, String category,
                                               String city, Date fromDate, Date toDate) {
        Datetime nowTime = System.now();
        Datetime fromDateTime = fromDate != null ? Datetime.newInstance(fromDate, Time.newInstance(0, 0, 0, 0)) : null;
        Datetime toDateTime = toDate != null ? Datetime.newInstance(toDate, Time.newInstance(23, 59, 59, 999)) : null;

        Set<Id> soslMatchIds = null;
        String sanitizedTerm = sanitizeSearchTerm(searchTerm);
        if (String.isNotBlank(sanitizedTerm)) {
            try {
                soslMatchIds = executeSoslSearch(sanitizedTerm);
            } catch (System.QueryException qe) {
                return new List<EventCard>();
            }
            if (soslMatchIds.isEmpty()) {
                return new List<EventCard>();
            }
        }

        List<Event__c> events;
        try {
            events = executeEventQuery(soslMatchIds, category, city, fromDateTime, toDateTime, nowTime);
        } catch (System.QueryException qe) {
            // Catches USER_MODE access restrictions when caller has no permission on Event__c
            return new List<EventCard>();
        } catch (System.SecurityException se) {
            return new List<EventCard>();
        }

        if (events == null || events.isEmpty()) {
            return new List<EventCard>();
        }

        Map<Id, List<Ticket_Tier__c>> tiersByEvent;
        try {
            tiersByEvent = queryTiersForEvents(events);
        } catch (Exception ex) {
            tiersByEvent = new Map<Id, List<Ticket_Tier__c>>();
        }

        List<EventCard> cards = new List<EventCard>();
        for (Event__c ev : events) {
            List<Ticket_Tier__c> eventTiers = tiersByEvent.containsKey(ev.Id) ? tiersByEvent.get(ev.Id) : new List<Ticket_Tier__c>();
            cards.add(buildEventCard(ev, eventTiers));
        }

        return cards;
    }

    /**
     * @description Fetch complete event details and tier breakdown for an event.
     */
    @AuraEnabled(cacheable=true)
    public static EventDetail getEventDetail(Id eventId) {
        if (eventId == null) {
            return null;
        }

        Datetime nowTime = System.now();
        List<Event__c> events;
        try {
            events = [
                SELECT Id, Name, Start_At__c, End_At__c, Capacity__c, Category__c,
                       Banner_Url__c, Description__c, Refund_Policy__c, Seats_Available__c,
                       Venue__r.Name, Venue__r.City__c, Venue__r.Street__c, Venue__r.State__c,
                       Venue__r.Postal_Code__c, Venue__r.Country__c, Venue__r.Accessibility_Notes__c
                FROM Event__c
                WHERE Id = :eventId
                  AND Is_Public__c = true
                  AND Status__c = 'On Sale'
                  AND (Sales_Open_At__c = null OR Sales_Open_At__c <= :nowTime)
                  AND (Sales_Close_At__c = null OR Sales_Close_At__c >= :nowTime)
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (Exception ex) {
            return null;
        }

        if (events.isEmpty()) {
            return null;
        }

        Event__c ev = events[0];
        List<Ticket_Tier__c> tiers;
        try {
            tiers = [
                SELECT Id, Name, Price__c, Available__c, Is_Sellable__c, Per_Order_Limit__c
                FROM Ticket_Tier__c
                WHERE Event__c = :ev.Id
                WITH USER_MODE
                ORDER BY Price__c ASC
            ];
        } catch (Exception ex) {
            tiers = new List<Ticket_Tier__c>();
        }

        EventDetail detail = new EventDetail();
        detail.header = buildEventCard(ev, tiers);
        detail.description = ev.Description__c;
        detail.refundPolicy = ev.Refund_Policy__c;
        detail.accessibilityNotes = ev.Venue__r != null ? ev.Venue__r.Accessibility_Notes__c : null;
        detail.venueAddress = buildVenueAddress(ev.Venue__r);
        detail.tiers = new List<TierRow>();

        for (Ticket_Tier__c tier : tiers) {
            TierRow row = new TierRow();
            row.id = tier.Id;
            row.name = tier.Name;
            row.price = tier.Price__c;
            row.available = tier.Available__c != null ? Integer.valueOf(tier.Available__c) : 0;
            row.isSellable = tier.Is_Sellable__c;
            row.perOrderLimit = tier.Per_Order_Limit__c != null ? Integer.valueOf(tier.Per_Order_Limit__c) : 4;
            detail.tiers.add(row);
        }

        return detail;
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    private static String sanitizeSearchTerm(String term) {
        if (String.isBlank(term)) {
            return null;
        }
        String cleaned = term.replaceAll('[^a-zA-Z0-9\\s]', ' ').trim();
        if (String.isBlank(cleaned)) {
            return null;
        }
        if (cleaned.length() > 100) {
            cleaned = cleaned.substring(0, 100);
        }
        return cleaned;
    }

    private static Set<Id> executeSoslSearch(String term) {
        Set<Id> ids = new Set<Id>();
        List<List<SObject>> searchResults = [
            FIND :term IN ALL FIELDS
            RETURNING Event__c(Id)
            WITH USER_MODE
        ];
        if (!searchResults.isEmpty()) {
            for (Event__c ev : (List<Event__c>)searchResults[0]) {
                ids.add(ev.Id);
            }
        }
        return ids;
    }

    private static List<Event__c> executeEventQuery(Set<Id> filterIds, String category, String city,
                                                    Datetime fromDateTime, Datetime toDateTime, Datetime nowTime) {
        String query = 'SELECT Id, Name, Start_At__c, End_At__c, Capacity__c, Category__c, ' +
                       'Banner_Url__c, Seats_Available__c, Venue__r.Name, Venue__r.City__c ' +
                       'FROM Event__c ' +
                       'WHERE Is_Public__c = true ' +
                       'AND Status__c = \'On Sale\' ' +
                       'AND (Sales_Open_At__c = null OR Sales_Open_At__c <= :nowTime) ' +
                       'AND (Sales_Close_At__c = null OR Sales_Close_At__c >= :nowTime) ';

        Map<String, Object> bindMap = new Map<String, Object>{
            'nowTime' => nowTime
        };

        if (filterIds != null) {
            query += 'AND Id IN :filterIds ';
            bindMap.put('filterIds', filterIds);
        }
        if (String.isNotBlank(category)) {
            query += 'AND Category__c = :category ';
            bindMap.put('category', category);
        }
        if (String.isNotBlank(city)) {
            query += 'AND Venue__r.City__c = :city ';
            bindMap.put('city', city);
        }
        if (fromDateTime != null) {
            query += 'AND Start_At__c >= :fromDateTime ';
            bindMap.put('fromDateTime', fromDateTime);
        }
        if (toDateTime != null) {
            query += 'AND Start_At__c <= :toDateTime ';
            bindMap.put('toDateTime', toDateTime);
        }

        query += 'ORDER BY Start_At__c ASC LIMIT 50';

        return Database.queryWithBinds(query, bindMap, AccessLevel.USER_MODE);
    }

    private static Map<Id, List<Ticket_Tier__c>> queryTiersForEvents(List<Event__c> events) {
        Set<Id> eventIds = new Set<Id>();
        for (Event__c ev : events) {
            eventIds.add(ev.Id);
        }

        List<Ticket_Tier__c> tiers = [
            SELECT Id, Name, Price__c, Available__c, Is_Sellable__c, Event__c
            FROM Ticket_Tier__c
            WHERE Event__c IN :eventIds
            WITH USER_MODE
            ORDER BY Price__c ASC
        ];

        Map<Id, List<Ticket_Tier__c>> tierMap = new Map<Id, List<Ticket_Tier__c>>();
        for (Ticket_Tier__c tier : tiers) {
            if (!tierMap.containsKey(tier.Event__c)) {
                tierMap.put(tier.Event__c, new List<Ticket_Tier__c>());
            }
            tierMap.get(tier.Event__c).add(tier);
        }
        return tierMap;
    }

    private static EventCard buildEventCard(Event__c ev, List<Ticket_Tier__c> tiers) {
        EventCard card = new EventCard();
        card.id = ev.Id;
        card.name = ev.Name;
        card.startAt = ev.Start_At__c;
        card.bannerUrl = ev.Banner_Url__c;
        card.category = ev.Category__c;
        card.venueName = ev.Venue__r != null ? ev.Venue__r.Name : null;
        card.city = ev.Venue__r != null ? ev.Venue__r.City__c : null;
        card.seatsAvailable = ev.Seats_Available__c != null ? Integer.valueOf(ev.Seats_Available__c) : 0;

        Decimal minPrice = null;
        for (Ticket_Tier__c tier : tiers) {
            if (tier.Is_Sellable__c == true && tier.Price__c != null) {
                if (minPrice == null || tier.Price__c < minPrice) {
                    minPrice = tier.Price__c;
                }
            }
        }
        card.priceFrom = minPrice;

        Decimal capacity = ev.Capacity__c != null ? ev.Capacity__c : 0;
        card.isNearlySoldOut = (capacity > 0 && card.seatsAvailable <= (capacity * 0.10));

        return card;
    }

    private static String buildVenueAddress(Venue__c venue) {
        if (venue == null) {
            return null;
        }
        List<String> parts = new List<String>();
        if (String.isNotBlank(venue.Street__c)) parts.add(venue.Street__c);
        if (String.isNotBlank(venue.City__c)) parts.add(venue.City__c);
        if (String.isNotBlank(venue.State__c)) parts.add(venue.State__c);
        if (String.isNotBlank(venue.Postal_Code__c)) parts.add(venue.Postal_Code__c);
        if (String.isNotBlank(venue.Country__c)) parts.add(venue.Country__c);
        return String.join(parts, ', ');
    }

    // ─── DTO Inner Classes ──────────────────────────────────────────────────────

    public class EventCard {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Datetime startAt;
        @AuraEnabled public String venueName;
        @AuraEnabled public String city;
        @AuraEnabled public String category;
        @AuraEnabled public Decimal priceFrom;
        @AuraEnabled public Integer seatsAvailable;
        @AuraEnabled public Boolean isNearlySoldOut;
        @AuraEnabled public String bannerUrl;
    }

    public class TierRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Integer available;
        @AuraEnabled public Boolean isSellable;
        @AuraEnabled public Integer perOrderLimit;
    }

    public class EventDetail {
        @AuraEnabled public EventCard header;
        @AuraEnabled public String description;
        @AuraEnabled public String refundPolicy;
        @AuraEnabled public String venueAddress;
        @AuraEnabled public String accessibilityNotes;
        @AuraEnabled public List<TierRow> tiers;
    }
}

