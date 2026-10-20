/**
 * @description Comprehensive test suite covering EpicEventz end-to-end services, concurrency,
 * automated Case/Task escalation, check-in validation, and REST API.
 * @author EpicEventz Development Team
 */
@IsTest
private class EevComprehensiveTest {

    @TestSetup
    static void setupTestData() {
        // Create Host Account
        Account host = new Account(
            Name = 'Nova Events Management',
            Commission_Rate__c = 10.00,
            KYC_Verification_Status__c = 'Verified'
        );
        insert host;

        // Create Attendee Contact
        Contact attendee = new Contact(
            FirstName = 'Alex',
            LastName = 'Riviera',
            Email = 'alex.riviera@example.com',
            AccountId = host.Id,
            VIP_Tier__c = 'VIP'
        );
        insert attendee;

        // Create Event Project (teammate's master object)
        Event_Project__c project = new Event_Project__c(
            Name = 'Tech Convergence 2026',
            Event_Title__c = 'Tech Convergence 2026',
            Host_Account__c = host.Id,
            Event_Category__c = 'Tech Conference',
            Event_Status__c = 'Published',
            Start_DateTime__c = System.now().addDays(14),
            End_DateTime__c = System.now().addDays(14).addHours(8),
            Total_Venue_Capacity__c = 1000,
            Total_Budget_Allocated__c = 50000.00
        );
        insert project;

        // Create Venue
        Venue__c venue = new Venue__c(
            Name = 'Grand Arena',
            City__c = 'Bengaluru',
            Capacity__c = 1000
        );
        insert venue;

        // Create Event__c (catalog event)
        Event__c ev = new Event__c(
            Name = 'Tech Convergence 2026',
            Organizer__c = host.Id,
            Venue__c = venue.Id,
            Status__c = 'On Sale',
            Is_Public__c = true,
            Capacity__c = 1000,
            Start_At__c = System.now().addDays(14),
            End_At__c = System.now().addDays(14).addHours(8)
        );
        insert ev;

        // Create Ticket Tiers
        Ticket_Tier__c tier1 = new Ticket_Tier__c(
            Event__c = ev.Id,
            Event_Project__c = project.Id,
            Name = 'VIP Pass',
            Tier_Name__c = 'VIP Lounge',
            Price__c = 5000.00,
            Base_Price__c = 5000.00,
            Allocated__c = 50,
            Total_Inventory__c = 50,
            Sold__c = 0,
            Sold_Count__c = 0,
            Is_Active__c = true
        );

        Ticket_Tier__c tier2 = new Ticket_Tier__c(
            Event__c = ev.Id,
            Event_Project__c = project.Id,
            Name = 'General Pass',
            Tier_Name__c = 'General Admission',
            Price__c = 1500.00,
            Base_Price__c = 1500.00,
            Allocated__c = 100,
            Total_Inventory__c = 100,
            Sold__c = 0,
            Sold_Count__c = 0,
            Is_Active__c = true
        );
        insert new List<Ticket_Tier__c>{ tier1, tier2 };
    }

    @IsTest
    static void testInventoryReservationAndRelease() {
        Ticket_Tier__c tier = [SELECT Id, Sold_Count__c FROM Ticket_Tier__c WHERE Name = 'VIP Pass' LIMIT 1];

        Test.startTest();
        EevInventoryService.reserveTierInventory(tier.Id, 5);
        Ticket_Tier__c updatedTier = [SELECT Id, Sold_Count__c FROM Ticket_Tier__c WHERE Id = :tier.Id];
        System.assertEquals(5, updatedTier.Sold_Count__c, 'Sold count should increase by 5');

        EevInventoryService.releaseTierInventory(tier.Id, 2);
        Ticket_Tier__c releasedTier = [SELECT Id, Sold_Count__c FROM Ticket_Tier__c WHERE Id = :tier.Id];
        System.assertEquals(3, releasedTier.Sold_Count__c, 'Sold count should decrease to 3');
        Test.stopTest();
    }

    @IsTest
    static void testCheckoutAndIdempotencyProtection() {
        Ticket_Tier__c tier = [SELECT Id FROM Ticket_Tier__c WHERE Name = 'General Pass' LIMIT 1];
        Contact attendee = [SELECT Id FROM Contact WHERE Email = 'alex.riviera@example.com' LIMIT 1];
        Event_Project__c project = [SELECT Id FROM Event_Project__c LIMIT 1];

        EevCheckoutService.CheckoutRequest req = new EevCheckoutService.CheckoutRequest();
        req.tierId = tier.Id;
        req.eventProjectId = project.Id;
        req.quantity = 2;
        req.buyerContactId = attendee.Id;
        req.unitPrice = 1500.00;
        req.idempotencyKey = 'IDEMP-TEST-KEY-001';
        req.paymentMethod = 'UPI';

        Test.startTest();
        // 1. Initial purchase
        EevCheckoutService.CheckoutResult res1 = EevCheckoutService.processCheckout(req);
        System.assert(res1.isSuccess, 'First purchase should succeed');
        System.assertEquals(false, res1.isReplay, 'Should not be marked as replay');
        System.assertEquals(2, res1.passIds.size(), 'Should have issued 2 ticket passes');

        // 2. Replay with identical idempotency key (UC-04 network drop scenario)
        EevCheckoutService.CheckoutResult res2 = EevCheckoutService.processCheckout(req);
        System.assert(res2.isSuccess, 'Replay request should succeed');
        System.assertEquals(true, res2.isReplay, 'Should be recognized as idempotent replay');
        System.assertEquals(res1.paymentId, res2.paymentId, 'Should return the same payment ID');
        Test.stopTest();
    }

    @IsTest
    static void testCheckinValidationAndRefusal() {
        Ticket_Tier__c tier = [SELECT Id FROM Ticket_Tier__c WHERE Name = 'VIP Pass' LIMIT 1];
        Contact attendee = [SELECT Id FROM Contact WHERE Email = 'alex.riviera@example.com' LIMIT 1];
        Event_Project__c project = [SELECT Id FROM Event_Project__c LIMIT 1];

        EevCheckoutService.CheckoutRequest req = new EevCheckoutService.CheckoutRequest();
        req.tierId = tier.Id;
        req.eventProjectId = project.Id;
        req.quantity = 1;
        req.buyerContactId = attendee.Id;
        req.unitPrice = 5000.00;
        req.idempotencyKey = 'CHECKIN-KEY-999';

        EevCheckoutService.CheckoutResult chk = EevCheckoutService.processCheckout(req);
        Ticket_Pass__c pass = [SELECT Id, Secure_QR_Token__c FROM Ticket_Pass__c WHERE Id = :chk.passIds[0]];

        Test.startTest();
        // 1. Valid Check-In
        EevTicketService.CheckinResult checkRes1 = EevTicketService.checkin(pass.Secure_QR_Token__c);
        System.assert(checkRes1.isSuccess, 'Valid token should grant entry');
        System.assert(checkRes1.message.contains('Access Granted') || checkRes1.message.contains('Welcome'), 'Message should indicate welcome');

        // 2. Duplicate Check-In (refusal)
        EevTicketService.CheckinResult checkRes2 = EevTicketService.checkin(pass.Secure_QR_Token__c);
        System.assertEquals(false, checkRes2.isSuccess, 'Duplicate token must refuse entry');
        System.assert(checkRes2.message.contains('already checked in'), 'Refusal reason must state already checked in');

        // 3. Controller test
        EevTicketService.CheckinResult ctrlRes = EevCheckinController.processCheckin('INVALID-TOKEN-XYZ');
        System.assertEquals(false, ctrlRes.isSuccess, 'Invalid token must fail');

        List<EevCheckinController.PassSummary> recent = EevCheckinController.getRecentPasses();
        System.assert(!recent.isEmpty(), 'Recent passes should return created pass');
        Test.stopTest();
    }

    @IsTest
    static void testHeroFeedbackEscalationToCaseAndTask() {
        Event_Project__c project = [SELECT Id FROM Event_Project__c LIMIT 1];
        Contact attendee = [SELECT Id FROM Contact WHERE Email = 'alex.riviera@example.com' LIMIT 1];

        Test.startTest();
        // Negative review (2 stars) with queue complaint
        EevFeedbackService.FeedbackSubmission negSub = new EevFeedbackService.FeedbackSubmission();
        negSub.eventProjectId = project.Id;
        negSub.reviewerContactId = attendee.Id;
        negSub.rating = 2;
        negSub.comments = 'The queue at the main entrance was chaotic and we waited 45 minutes in the rain!';

        EevFeedbackService.FeedbackResult res = EevFeedbackService.processFeedback(negSub);
        System.assertEquals('Negative', res.sentiment, 'Sentiment should be Negative');
        System.assertEquals('Crowd & Queues', res.issueTag, 'Topic should be Crowd & Queues');
        System.assertEquals(true, res.wasEscalated, '2-star feedback must escalate');
        System.assertNotEquals(null, res.caseId, 'Service Case should be created');
        System.assertNotEquals(null, res.taskId, 'Remediation Task should be created');

        // Verify Case record
        Case createdCase = [SELECT Id, Priority, Subject, ContactId FROM Case WHERE Id = :res.caseId];
        System.assertEquals('High', createdCase.Priority, 'Escalated case must have High priority');
        System.assertEquals(attendee.Id, createdCase.ContactId, 'Case should link to reviewer contact');

        // Verify Task record
        Task createdTask = [SELECT Id, Priority, ActivityDate, WhatId FROM Task WHERE Id = :res.taskId];
        System.assertEquals('High', createdTask.Priority, 'Task must be High priority');
        System.assertEquals(Date.today().addDays(1), createdTask.ActivityDate, 'Task should be due in 1 day');
        System.assertEquals(createdCase.Id, createdTask.WhatId, 'Task should reference the Case');
        Test.stopTest();
    }

    @IsTest
    static void testRestOrderApi() {
        Ticket_Tier__c tier = [SELECT Id FROM Ticket_Tier__c WHERE Name = 'General Pass' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/epiceventz/v1/orders';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        EevOrderRestResource.RestOrderRequest body = new EevOrderRestResource.RestOrderRequest();
        body.tierId = (String)tier.Id;
        body.quantity = 1;
        body.buyerEmail = 'external.buyer@example.com';
        body.buyerLastName = 'ExternalBuyer';
        body.idempotencyKey = 'REST-IDEMP-888';
        body.unitPrice = 1500.00;

        Test.startTest();
        EevOrderRestResource.RestOrderResponse apiRes = EevOrderRestResource.createOrder(body);
        System.assert(apiRes.success, 'REST booking API should succeed');
        System.assertNotEquals(null, apiRes.bookingOrderId, 'Should return booking order ID');
        Test.stopTest();
    }

    @IsTest
    static void testReconciliationBatch() {
        Ticket_Tier__c tier = [SELECT Id, Sold_Count__c FROM Ticket_Tier__c WHERE Name = 'VIP Pass' LIMIT 1];
        // Intentionally simulate drift
        tier.Sold_Count__c = 99;
        update tier;

        Test.startTest();
        Database.executeBatch(new EevInventoryReconciliationBatch(), 10);
        Test.stopTest();

        Ticket_Tier__c repaired = [SELECT Id, Sold_Count__c FROM Ticket_Tier__c WHERE Id = :tier.Id];
        System.assertEquals(0, repaired.Sold_Count__c, 'Reconciliation batch should repair drifted counter back to 0');
    }
}

