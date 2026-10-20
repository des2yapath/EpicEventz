/**
 * @description Domain service for ticket and entry pass validation and door check-in processing.
 * @author EpicEventz Development Team
 */
public with sharing class EevTicketService {

    public class CheckinResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String message;
        @AuraEnabled public String attendeeName;
        @AuraEnabled public String tierName;
        @AuraEnabled public String seatAssignment;
        @AuraEnabled public Datetime checkInTime;
    }

    /**
     * @description Validates and checks in an attendee using their unique QR token.
     */
    public static CheckinResult checkin(String token) {
        CheckinResult res = new CheckinResult();

        if (String.isBlank(token)) {
            res.isSuccess = false;
            res.message = 'Please provide or scan a valid QR token.';
            return res;
        }

        List<Ticket_Pass__c> passes = [
            SELECT Id, Status__c, Check_In_Timestamp__c, Table_Seat_Assignment__c,
                   Attendee_Contact__r.Name, Ticket_Tier__r.Name
            FROM Ticket_Pass__c
            WHERE Secure_QR_Token__c = :token.trim()
            WITH USER_MODE
            LIMIT 1
        ];

        if (passes.isEmpty()) {
            res.isSuccess = false;
            res.message = 'Invalid Entry Pass: No ticket found matching token ' + token;
            EevLogger.warn('EevTicketService', res.message, null, 'Verify badge printing or re-issue token.');
            return res;
        }

        Ticket_Pass__c pass = passes[0];
        res.attendeeName = pass.Attendee_Contact__r != null ? pass.Attendee_Contact__r.Name : 'Guest Attendee';
        res.tierName = pass.Ticket_Tier__r != null ? pass.Ticket_Tier__r.Name : 'General';
        res.seatAssignment = pass.Table_Seat_Assignment__c;

        if (pass.Status__c == 'Checked-In') {
            res.isSuccess = false;
            res.message = 'Entry Refused: Ticket was already checked in at ' + pass.Check_In_Timestamp__c;
            EevLogger.warn('EevTicketService', res.message, new List<Id>{ pass.Id }, 'Check with gate supervisor.');
            return res;
        }

        if (pass.Status__c == 'Cancelled') {
            res.isSuccess = false;
            res.message = 'Entry Refused: This ticket has been cancelled or refunded.';
            EevLogger.warn('EevTicketService', res.message, new List<Id>{ pass.Id }, 'Direct attendee to help desk.');
            return res;
        }

        // Successfully check in
        pass.Status__c = 'Checked-In';
        pass.Check_In_Timestamp__c = System.now();
        update as user pass;

        res.isSuccess = true;
        res.checkInTime = pass.Check_In_Timestamp__c;
        res.message = 'Welcome! Successfully checked in ' + res.attendeeName + ' (' + res.tierName + ')';

        EevLogger.info('EevTicketService', 'Checked in pass ' + pass.Id, new List<Id>{ pass.Id });
        return res;
    }
}

