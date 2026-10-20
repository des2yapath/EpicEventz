/**
 * @description Nightly Batch & Schedulable job reconciling ticket counters and repairing counter drift.
 * @author EpicEventz Development Team
 */
public with sharing class EevInventoryReconciliationBatch implements Database.Batchable<sObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Sold_Count__c, Sold__c
            FROM Ticket_Tier__c
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Ticket_Tier__c> scope) {
        Set<Id> tierIds = new Set<Id>();
        for (Ticket_Tier__c t : scope) {
            tierIds.add(t.Id);
        }

        // Aggregate actual valid passes
        Map<Id, Integer> actualCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Ticket_Tier__c tierId, COUNT(Id) cnt
            FROM Ticket_Pass__c
            WHERE Ticket_Tier__c IN :tierIds AND Status__c != 'Cancelled'
            GROUP BY Ticket_Tier__c
        ]) {
            actualCounts.put((Id)ar.get('tierId'), (Integer)ar.get('cnt'));
        }

        List<Ticket_Tier__c> toUpdate = new List<Ticket_Tier__c>();
        for (Ticket_Tier__c tier : scope) {
            Integer actual = actualCounts.containsKey(tier.Id) ? actualCounts.get(tier.Id) : 0;
            Integer recorded = tier.Sold_Count__c != null ? (Integer)tier.Sold_Count__c : 0;

            if (actual != recorded) {
                // Drift detected! Repair it.
                tier.Sold_Count__c = actual;
                tier.Sold__c = actual;
                toUpdate.add(tier);

                EevLogger.warn('EevInventoryReconciliationBatch',
                    'Drift repaired on tier ' + tier.Name + ': was ' + recorded + ', corrected to ' + actual,
                    new List<Id>{ tier.Id }, 'Audit previous transactions for uncommitted inventory.');
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false, AccessLevel.USER_MODE);
        }
    }

    public void finish(Database.BatchableContext bc) {
        EevLogger.info('EevInventoryReconciliationBatch', 'Completed nightly inventory reconciliation batch.', null);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EevInventoryReconciliationBatch(), 100);
    }
}

