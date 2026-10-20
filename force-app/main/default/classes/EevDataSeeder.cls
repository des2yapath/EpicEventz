/**
 * @description Idempotent demo data seeder for EpicEventz.
 * Populates operational Event_Project__c records, catalog Event__c records, ticket tiers, and attendance tickets.
 * Note on sharing: As explicitly permitted in §8 of the specification, public without sharing
 * is used strictly for this administrative data seeder to create test accounts, venues, and events
 * across boundaries. All production application code strictly enforces with sharing.
 * @author EpicEventz Development Team
 */
public without sharing class EevDataSeeder {

    public static final String ORG_NOVA = 'Nova Events Inc.';
    public static final String ORG_BELLA = 'Bella Live';
    public static final String VENUE_AURORA = 'Aurora Convention Centre';
    public static final String VENUE_HARBOUR = 'Harbour Hall';
    public static final String EVENT_AURORA = 'Aurora Tech Summit 2026';
    public static final String EVENT_MUSIC = 'Nova Music Night';
    public static final String EVENT_SECRET = 'Secret Gala';
    public static final String EVENT_WINTER = 'Winter Expo 2025';

    /**
     * @description Populates the exact acceptance testing dataset. Idempotent.
     */
    public static void seed() {
        // 1. Organizers (Accounts)
        Account novaAcc = getOrCreateAccount(ORG_NOVA);
        Account bellaAcc = getOrCreateAccount(ORG_BELLA);

        // 2. Venues
        Venue__c auroraVenue = getOrCreateVenue(VENUE_AURORA, 'Bengaluru', 'India', 1200);
        Venue__c harbourVenue = getOrCreateVenue(VENUE_HARBOUR, 'Mumbai', 'India', 400);

        Date today = Date.today();

        // 3. Event: Aurora Tech Summit 2026 (The only visible event in public search)
        Datetime auroraStart = Datetime.newInstance(today.addDays(30), Time.newInstance(18, 0, 0, 0));
        Datetime auroraEnd = Datetime.newInstance(today.addDays(30), Time.newInstance(23, 0, 0, 0));
        Datetime auroraSalesOpen = Datetime.newInstance(today.addDays(-7), Time.newInstance(0, 0, 0, 0));
        Datetime auroraSalesClose = Datetime.newInstance(today.addDays(29), Time.newInstance(23, 59, 59, 0));

        Event_Project__c auroraProject = getOrCreateProject(EVENT_AURORA, novaAcc.Id, 'Tech Conference', 'Published', 500);

        Event__c auroraEvent = getOrCreateEvent(
            EVENT_AURORA, novaAcc.Id, auroraVenue.Id, 'On Sale', true, 500, 'Technology',
            auroraStart, auroraEnd, auroraSalesOpen, auroraSalesClose,
            'Annual flagship technology summit bringing together cloud architects and AI engineers.',
            'Full refund up to 7 days before the event.', 5.0
        );

        // Tiers for Aurora
        Ticket_Tier__c vipTier = getOrCreateTier(auroraEvent.Id, auroraProject.Id, 'VIP', 8000.00, 50, 12);
        Ticket_Tier__c stdTier = getOrCreateTier(auroraEvent.Id, auroraProject.Id, 'Standard', 3500.00, 300, 80);
        Ticket_Tier__c ebTier = getOrCreateTier(auroraEvent.Id, auroraProject.Id, 'Early Bird', 1500.00, 40, 40);

        // Tickets for Aurora: VIP (10 Checked In, 2 Issued = 12 total)
        syncTickets(auroraEvent.Id, vipTier.Id, 'AURORA-VIP-', 12, 10);
        // Standard: 80 Issued
        syncTickets(auroraEvent.Id, stdTier.Id, 'AURORA-STD-', 80, 0);
        // Early Bird: 40 Issued
        syncTickets(auroraEvent.Id, ebTier.Id, 'AURORA-EB-', 40, 0);

        // 4. Event: Nova Music Night (Draft - should NOT appear in browse)
        Datetime musicStart = Datetime.newInstance(today.addDays(14), Time.newInstance(19, 0, 0, 0));
        Datetime musicEnd = Datetime.newInstance(today.addDays(14), Time.newInstance(23, 0, 0, 0));
        Event_Project__c musicProject = getOrCreateProject(EVENT_MUSIC, novaAcc.Id, 'Live Concert', 'Draft', 400);

        Event__c musicEvent = getOrCreateEvent(
            EVENT_MUSIC, novaAcc.Id, harbourVenue.Id, 'Draft', true, 400, 'Music',
            musicStart, musicEnd, null, null, 'Live indie music night.', null, null
        );
        Ticket_Tier__c musicTier = getOrCreateTier(musicEvent.Id, musicProject.Id, 'General', 2000.00, 400, 0);

        // 5. Event: Secret Gala (Is_Public = false - should NOT appear in browse)
        Datetime galaStart = Datetime.newInstance(today.addDays(45), Time.newInstance(20, 0, 0, 0));
        Datetime galaEnd = Datetime.newInstance(today.addDays(45), Time.newInstance(23, 59, 0, 0));
        Event_Project__c galaProject = getOrCreateProject(EVENT_SECRET, novaAcc.Id, 'Tech Conference', 'Published', 200);

        Event__c galaEvent = getOrCreateEvent(
            EVENT_SECRET, novaAcc.Id, harbourVenue.Id, 'On Sale', false, 200, 'Business',
            galaStart, galaEnd, null, null, 'Private executive gala.', null, null
        );
        Ticket_Tier__c galaTier = getOrCreateTier(galaEvent.Id, galaProject.Id, 'Executive Pass', 12000.00, 200, 0);

        // 6. Event: Winter Expo 2025 (Sales window closed - should NOT appear in browse)
        Datetime winterStart = Datetime.newInstance(today.addDays(-30), Time.newInstance(10, 0, 0, 0));
        Datetime winterEnd = Datetime.newInstance(today.addDays(-30), Time.newInstance(18, 0, 0, 0));
        Datetime winterSalesClose = Datetime.newInstance(today.addDays(-31), Time.newInstance(23, 59, 59, 0));
        Event_Project__c winterProject = getOrCreateProject(EVENT_WINTER, novaAcc.Id, 'Tech Conference', 'Completed', 300);

        Event__c winterEvent = getOrCreateEvent(
            EVENT_WINTER, novaAcc.Id, auroraVenue.Id, 'On Sale', true, 300, 'Community',
            winterStart, winterEnd, null, winterSalesClose, 'Winter lifestyle expo.', null, null
        );
        Ticket_Tier__c winterTier = getOrCreateTier(winterEvent.Id, winterProject.Id, 'Expo Pass', 1000.00, 300, 0);
    }

    /**
     * @description Deletes all records created by seed() in safe dependency order.
     */
    public static void unseed() {
        List<Ticket__c> tickets = [
            SELECT Id FROM Ticket__c
            WHERE Event__r.Name IN (:EVENT_AURORA, :EVENT_MUSIC, :EVENT_SECRET, :EVENT_WINTER)
        ];
        if (!tickets.isEmpty()) {
            delete tickets;
        }

        List<Ticket_Tier__c> tiers = [
            SELECT Id FROM Ticket_Tier__c
            WHERE Event__r.Name IN (:EVENT_AURORA, :EVENT_MUSIC, :EVENT_SECRET, :EVENT_WINTER)
        ];
        if (!tiers.isEmpty()) {
            delete tiers;
        }

        List<Event__c> events = [
            SELECT Id FROM Event__c
            WHERE Name IN (:EVENT_AURORA, :EVENT_MUSIC, :EVENT_SECRET, :EVENT_WINTER)
        ];
        if (!events.isEmpty()) {
            delete events;
        }

        List<Event_Project__c> projects = [
            SELECT Id FROM Event_Project__c
            WHERE Name IN (:EVENT_AURORA, :EVENT_MUSIC, :EVENT_SECRET, :EVENT_WINTER)
        ];
        if (!projects.isEmpty()) {
            delete projects;
        }

        List<Venue__c> venues = [
            SELECT Id FROM Venue__c
            WHERE Name IN (:VENUE_AURORA, :VENUE_HARBOUR)
        ];
        if (!venues.isEmpty()) {
            delete venues;
        }

        List<Account> accounts = [
            SELECT Id FROM Account
            WHERE Name IN (:ORG_NOVA, :ORG_BELLA)
        ];
        if (!accounts.isEmpty()) {
            delete accounts;
        }
    }

    private static Account getOrCreateAccount(String name) {
        List<Account> existing = [SELECT Id, Name FROM Account WHERE Name = :name LIMIT 1];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Venue__c getOrCreateVenue(String name, String city, String country, Integer capacity) {
        List<Venue__c> existing = [SELECT Id, Name FROM Venue__c WHERE Name = :name LIMIT 1];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        Venue__c v = new Venue__c(
            Name = name,
            City__c = city,
            Country__c = country,
            Capacity__c = capacity,
            Street__c = '123 Exhibition Way',
            State__c = 'KA',
            Postal_Code__c = '560001',
            Accessibility_Notes__c = 'Wheelchair accessible ramps and elevators available at Gate 2.'
        );
        insert v;
        return v;
    }

    private static Event_Project__c getOrCreateProject(String name, Id hostAccountId, String category, String status, Integer capacity) {
        List<Event_Project__c> existing = [SELECT Id, Name FROM Event_Project__c WHERE Name = :name LIMIT 1];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        Event_Project__c p = new Event_Project__c(
            Name = name,
            Event_Title__c = name,
            Host_Account__c = hostAccountId,
            Event_Category__c = category,
            Event_Status__c = status,
            Total_Venue_Capacity__c = capacity,
            Total_Budget_Allocated__c = 50000.00
        );
        insert p;
        return p;
    }

    private static Event__c getOrCreateEvent(String name, Id orgId, Id venueId, String status,
                                             Boolean isPublic, Integer capacity, String category,
                                             Datetime startAt, Datetime endAt,
                                             Datetime salesOpen, Datetime salesClose,
                                             String description, String refundPolicy, Decimal feePercent) {
        List<Event__c> existing = [SELECT Id, Name FROM Event__c WHERE Name = :name LIMIT 1];
        Event__c ev = existing.isEmpty() ? new Event__c(Name = name) : existing[0];

        ev.Organizer__c = orgId;
        ev.Venue__c = venueId;
        ev.Status__c = status;
        ev.Is_Public__c = isPublic;
        ev.Capacity__c = capacity;
        ev.Category__c = category;
        ev.Start_At__c = startAt;
        ev.End_At__c = endAt;
        ev.Sales_Open_At__c = salesOpen;
        ev.Sales_Close_At__c = salesClose;
        ev.Description__c = description;
        ev.Refund_Policy__c = refundPolicy;
        ev.Platform_Fee_Percent__c = feePercent;
        ev.Banner_Url__c = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800';

        upsert ev;
        return ev;
    }

    private static Ticket_Tier__c getOrCreateTier(Id eventId, Id projectId, String name, Decimal price,
                                                  Integer allocated, Integer sold) {
        List<Ticket_Tier__c> existing = [
            SELECT Id, Name FROM Ticket_Tier__c
            WHERE Event__c = :eventId AND Name = :name
            LIMIT 1
        ];
        Ticket_Tier__c t;
        if (existing.isEmpty()) {
            t = new Ticket_Tier__c(Event__c = eventId, Name = name, Event_Project__c = projectId);
        } else {
            t = existing[0];
        }
        t.Price__c = price;
        t.Base_Price__c = price;
        t.Allocated__c = allocated;
        t.Total_Inventory__c = allocated;
        t.Sold__c = sold;
        t.Sold_Count__c = sold;
        t.Held__c = 0;
        t.Per_Order_Limit__c = 4;
        t.Is_Active__c = true;
        upsert t;
        return t;
    }

    private static void syncTickets(Id eventId, Id tierId, String prefix, Integer totalCount, Integer checkedInCount) {
        List<Ticket__c> existingTickets = [
            SELECT Id, Code__c, Status__c
            FROM Ticket__c
            WHERE Event__c = :eventId AND Ticket_Tier__c = :tierId
        ];

        Map<String, Ticket__c> codeMap = new Map<String, Ticket__c>();
        for (Ticket__c t : existingTickets) {
            codeMap.put(t.Code__c, t);
        }

        List<Ticket__c> ticketsToInsert = new List<Ticket__c>();
        List<Ticket__c> ticketsToUpdate = new List<Ticket__c>();

        for (Integer i = 1; i <= totalCount; i++) {
            String suffix = String.valueOf(1000 + i);
            String fullCode = (prefix + suffix + 'XYZ1234567890').substring(0, 24);
            String targetStatus = (i <= checkedInCount) ? 'Checked In' : 'Issued';

            if (codeMap.containsKey(fullCode)) {
                Ticket__c existing = codeMap.get(fullCode);
                if (existing.Status__c != targetStatus) {
                    existing.Status__c = targetStatus;
                    ticketsToUpdate.add(existing);
                }
            } else {
                ticketsToInsert.add(new Ticket__c(
                    Event__c = eventId,
                    Ticket_Tier__c = tierId,
                    Code__c = fullCode,
                    Status__c = targetStatus,
                    Price_Paid__c = 100.00
                ));
            }
        }

        if (!ticketsToInsert.isEmpty()) {
            insert ticketsToInsert;
        }
        if (!ticketsToUpdate.isEmpty()) {
            update ticketsToUpdate;
        }
    }
}
