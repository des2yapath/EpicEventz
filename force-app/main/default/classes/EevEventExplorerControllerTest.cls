/**
 * @description Comprehensive test suite for EevEventExplorerController.
 * Follows strict sentence-based naming conventions and verifies browse predicates,
 * SOSL sanitization, security enforcement, and tier pricing.
 * @author EpicEventz Development Team
 */
@isTest
private class EevEventExplorerControllerTest {

    @testSetup
    static void setupTestData() {
        EevDataSeeder.seed();
    }

    @isTest
    static void returnsOnlyPublicOnSaleEventsWithAnOpenSalesWindow() {
        Test.startTest();
        List<EevEventExplorerController.EventCard> cards = EevEventExplorerController.searchEvents(null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, cards.size(), 'Only one event should be visible in public browse');
        Event__c aurora = [SELECT Id, Name FROM Event__c WHERE Name = :EevDataSeeder.EVENT_AURORA LIMIT 1];
        System.assertEquals(aurora.Id, cards[0].id, 'The single visible event must be Aurora Tech Summit 2026');
        System.assertEquals('Aurora Tech Summit 2026', cards[0].name);
    }

    @isTest
    static void soldOutTierIsReturnedButNotSellable() {
        Event__c aurora = [SELECT Id FROM Event__c WHERE Name = :EevDataSeeder.EVENT_AURORA LIMIT 1];

        Test.startTest();
        EevEventExplorerController.EventDetail detail = EevEventExplorerController.getEventDetail(aurora.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Event detail should not be null');
        System.assertNotEquals(null, detail.tiers, 'Tiers list should be populated');

        EevEventExplorerController.TierRow earlyBirdTier = null;
        for (EevEventExplorerController.TierRow row : detail.tiers) {
            if (row.name == 'Early Bird') {
                earlyBirdTier = row;
                break;
            }
        }

        System.assertNotEquals(null, earlyBirdTier, 'Early Bird tier must be present in detail');
        System.assertEquals(0, earlyBirdTier.available, 'Early Bird available seats must be 0');
        System.assertEquals(false, earlyBirdTier.isSellable, 'Sold-out tier must have isSellable == false');
    }

    @isTest
    static void priceFromIgnoresSoldOutTiers() {
        Test.startTest();
        List<EevEventExplorerController.EventCard> cards = EevEventExplorerController.searchEvents(null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, cards.size());
        System.assertEquals(3500.00, cards[0].priceFrom, 'priceFrom must be 3500 (Standard tier), ignoring 1500 Early Bird');
    }

    @isTest
    static void categoryAndCityFiltersNarrowTheResultSet() {
        Date futureDate = Date.today().addDays(35);

        Test.startTest();
        // Matching Category
        List<EevEventExplorerController.EventCard> techCards = EevEventExplorerController.searchEvents(null, 'Technology', null, null, null);
        System.assertEquals(1, techCards.size(), 'Should find Aurora under Technology category');

        // Non-matching Category
        List<EevEventExplorerController.EventCard> musicCards = EevEventExplorerController.searchEvents(null, 'Music', null, null, null);
        System.assertEquals(0, musicCards.size(), 'Music event is in Draft and should not appear');

        // Matching City
        List<EevEventExplorerController.EventCard> blrCards = EevEventExplorerController.searchEvents(null, null, 'Bengaluru', null, null);
        System.assertEquals(1, blrCards.size(), 'Should find Aurora in Bengaluru');

        // Non-matching City
        List<EevEventExplorerController.EventCard> delhiCards = EevEventExplorerController.searchEvents(null, null, 'Delhi', null, null);
        System.assertEquals(0, delhiCards.size(), 'No public events in Delhi');

        // Date range filter
        List<EevEventExplorerController.EventCard> inDateCards = EevEventExplorerController.searchEvents(null, null, null, Date.today(), futureDate);
        System.assertEquals(1, inDateCards.size(), 'Aurora starts within the date range');
        Test.stopTest();
    }

    @isTest
    static void freeTextSearchMatchesEventDescriptionAndVenueName() {
        Event__c aurora = [SELECT Id FROM Event__c WHERE Name = :EevDataSeeder.EVENT_AURORA LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ aurora.Id });

        Test.startTest();
        List<EevEventExplorerController.EventCard> descCards = EevEventExplorerController.searchEvents('architects', null, null, null, null);
        System.assertEquals(1, descCards.size(), 'Search by description term must return Aurora');

        List<EevEventExplorerController.EventCard> venueCards = EevEventExplorerController.searchEvents('Aurora', null, null, null, null);
        System.assertEquals(1, venueCards.size(), 'Search by venue term must return Aurora');
        Test.stopTest();
    }

    @isTest
    static void sanitisesSearchTermWithSoslReservedCharacters() {
        Event__c aurora = [SELECT Id FROM Event__c WHERE Name = :EevDataSeeder.EVENT_AURORA LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ aurora.Id });

        Test.startTest();
        // Term with reserved characters: ?, (, ", \
        String dirtyTerm = 'architects? ("cloud") \\';
        List<EevEventExplorerController.EventCard> cards = EevEventExplorerController.searchEvents(dirtyTerm, null, null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, cards, 'Sanitised SOSL search should not throw exceptions');
        System.assertEquals(1, cards.size(), 'Should successfully find Aurora despite special chars');
    }

    @isTest
    static void hidesEventsIfTheCallerHasNoAccess() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name IN ('Standard User', 'Minimum Access - Salesforce') LIMIT 1];
        User restrictedUser = new User(
            FirstName = 'Test',
            LastName = 'AttendeeWithoutPerms',
            Email = 'restricted@example.com',
            Username = 'restricted_' + Crypto.getRandomInteger() + '@example.com',
            Alias = 'ruser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = stdProfile.Id
        );
        insert restrictedUser;

        System.runAs(restrictedUser) {
            Test.startTest();
            List<EevEventExplorerController.EventCard> cards = EevEventExplorerController.searchEvents(null, null, null, null, null);
            Test.stopTest();

            System.assertEquals(0, cards.size(), 'User without object access must get 0 results, no exception');
        }
    }

    @isTest
    static void getEventDetailReturnsNullForAnInvisibleEvent() {
        Event__c secretGala = [SELECT Id FROM Event__c WHERE Name = :EevDataSeeder.EVENT_SECRET LIMIT 1];

        Test.startTest();
        EevEventExplorerController.EventDetail detail = EevEventExplorerController.getEventDetail(secretGala.Id);
        Test.stopTest();

        System.assertEquals(null, detail, 'Private event must return null detail, not a partially-populated object');

        // Test with null ID
        EevEventExplorerController.EventDetail nullDetail = EevEventExplorerController.getEventDetail(null);
        System.assertEquals(null, nullDetail, 'Null eventId must return null');
    }

    @isTest
    static void seedingTwiceCreatesNoDuplicates() {
        Test.startTest();
        // Re-run seed
        EevDataSeeder.seed();
        Test.stopTest();

        List<Event__c> auroraList = [SELECT Id FROM Event__c WHERE Name = :EevDataSeeder.EVENT_AURORA];
        System.assertEquals(1, auroraList.size(), 'Aurora Tech Summit must not be duplicated');

        List<Ticket_Tier__c> tiers = [
            SELECT Id, Name, Sold__c,
                   (SELECT Id FROM Tickets__r)
            FROM Ticket_Tier__c
            WHERE Event__c = :auroraList[0].Id
        ];
        for (Ticket_Tier__c t : tiers) {
            System.assertEquals(t.Sold__c, t.Tickets__r.size(), 'Ticket count for ' + t.Name + ' must equal Sold__c');
        }

        // Test unseed execution
        EevDataSeeder.unseed();
        List<Event__c> afterUnseed = [SELECT Id FROM Event__c WHERE Name = :EevDataSeeder.EVENT_AURORA];
        System.assertEquals(0, afterUnseed.size(), 'unseed() must clean up all created events');
    }
}

