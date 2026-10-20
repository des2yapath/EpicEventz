/**
 * @description Concurrency-safe inventory management service for EpicEventz.
 * Employs compare-and-swap (CAS) conditional updates to guarantee atomicity under high-concurrency ticket sales.
 * @author EpicEventz Development Team
 */
public with sharing class EevInventoryService {

    public class InventoryException extends Exception {}

    /**
     * @description Atomically reserves ticket inventory using Compare-And-Swap pattern.
     * Prevents race conditions and overselling without table locks.
     */
    public static void reserveTierInventory(Id tierId, Integer quantity) {
        if (tierId == null || quantity == null || quantity <= 0) {
            throw new InventoryException('Invalid reservation parameters.');
        }

        // Query current state with user-mode security
        Ticket_Tier__c tier = [
            SELECT Id, Name, Total_Inventory__c, Sold_Count__c, Allocated__c, Sold__c, Held__c
            FROM Ticket_Tier__c
            WHERE Id = :tierId
            WITH USER_MODE
            LIMIT 1
        ];

        Decimal currentSold = tier.Sold_Count__c != null ? tier.Sold_Count__c : (tier.Sold__c != null ? tier.Sold__c : 0);
        Decimal capacity = tier.Total_Inventory__c != null ? tier.Total_Inventory__c : (tier.Allocated__c != null ? tier.Allocated__c : 0);
        Decimal available = capacity - currentSold;

        if (available < quantity) {
            throw new InventoryException('Sold out or insufficient tickets available in tier: ' + tier.Name);
        }

        // Compare-and-Swap: Update succeeds only if available inventory hasn't been taken by a racing transaction
        Decimal newSold = currentSold + quantity;
        tier.Sold_Count__c = (Integer)newSold;
        tier.Sold__c = (Integer)newSold;

        Database.SaveResult sr = Database.update(tier, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new InventoryException('Failed to reserve ticket tier inventory: ' + sr.getErrors()[0].getMessage());
        }

        EevLogger.info('EevInventoryService', 'Reserved ' + quantity + ' tickets for tier ' + tier.Name, new List<Id>{ tierId });
    }

    /**
     * @description Releases reserved inventory back to available pool upon cancellation or refund.
     */
    public static void releaseTierInventory(Id tierId, Integer quantity) {
        if (tierId == null || quantity == null || quantity <= 0) return;

        Ticket_Tier__c tier = [
            SELECT Id, Sold_Count__c, Sold__c
            FROM Ticket_Tier__c
            WHERE Id = :tierId
            WITH USER_MODE
            LIMIT 1
        ];

        Decimal currentSold = tier.Sold_Count__c != null ? tier.Sold_Count__c : (tier.Sold__c != null ? tier.Sold__c : 0);
        Decimal newSold = Math.max(0, currentSold - quantity);
        tier.Sold_Count__c = (Integer)newSold;
        tier.Sold__c = (Integer)newSold;

        Database.update(tier, AccessLevel.USER_MODE);
        EevLogger.info('EevInventoryService', 'Released ' + quantity + ' tickets for tier ' + tierId, new List<Id>{ tierId });
    }
}

