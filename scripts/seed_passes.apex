// Seed sample Booking Orders and Ticket Passes
List<Ticket_Tier__c> tiers = [SELECT Id, Event_Project__c, Price__c FROM Ticket_Tier__c WHERE Event_Project__c != null LIMIT 2];
List<Contact> contacts = [SELECT Id, Name, Email FROM Contact LIMIT 3];

if (!tiers.isEmpty() && !contacts.isEmpty()) {
    Ticket_Tier__c tier = tiers[0];
    Contact buyer = contacts[0];

    // Order 1
    Booking_Order__c bo1 = new Booking_Order__c(
        Buyer_Contact__c = buyer.Id,
        Event_Project__c = tier.Event_Project__c,
        Total_Amount_Paid__c = tier.Price__c * 2,
        Payment_Status__c = 'Success',
        Gateway_Transaction_Id__c = 'GW-STRIPE-SEED-001'
    );
    insert bo1;

    Ticket_Pass__c p1 = new Ticket_Pass__c(
        Booking_Order__c = bo1.Id,
        Ticket_Tier__c = tier.Id,
        Attendee_Contact__c = buyer.Id,
        Status__c = 'Valid',
        Secure_QR_Token__c = 'PASS-TOKEN-DEMO-VIP-001',
        Table_Seat_Assignment__c = 'Table A - Seat 1'
    );
    Ticket_Pass__c p2 = new Ticket_Pass__c(
        Booking_Order__c = bo1.Id,
        Ticket_Tier__c = tier.Id,
        Attendee_Contact__c = contacts.size() > 1 ? contacts[1].Id : buyer.Id,
        Status__c = 'Valid',
        Secure_QR_Token__c = 'PASS-TOKEN-DEMO-VIP-002',
        Table_Seat_Assignment__c = 'Table A - Seat 2'
    );
    insert new List<Ticket_Pass__c>{ p1, p2 };

    // Payment Ledger record
    Payment__c pay1 = new Payment__c(
        Amount__c = tier.Price__c * 2,
        Status__c = 'Captured',
        Method__c = 'Card',
        Idempotency_Key__c = 'IDEMP-SEED-KEY-001',
        Captured_At__c = System.now()
    );
    insert pay1;

    // Feedback Intelligence sample
    Feedback_Intelligence__c fb = new Feedback_Intelligence__c(
        Reviewer__c = buyer.Id,
        Event_Project__c = tier.Event_Project__c,
        Rating__c = 5,
        Comments__c = 'Flawless production, breathtaking lighting, and smooth entry experience!',
        AI_Sentiment__c = 'Positive',
        Actionable_Issue_Tag__c = 'Production/Staging'
    );
    insert fb;

    System.debug('Seeded demo orders, passes, payments, and feedback successfully!');
}

