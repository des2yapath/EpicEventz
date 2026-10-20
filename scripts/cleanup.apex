delete [SELECT Id FROM Ticket__c];
delete [SELECT Id FROM Ticket_Tier__c];
delete [SELECT Id FROM Event__c];
System.debug('Existing test data cleaned successfully.');

