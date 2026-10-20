/**
 * @description Centralized observability and error logging utility for EpicEventz.
 * Logs structured events to Log__c with transaction correlation IDs and PII masking.
 * @author EpicEventz Development Team
 */
public with sharing class EevLogger {

    private static String currentCorrelationId;

    public static String getCorrelationId() {
        if (currentCorrelationId == null) {
            currentCorrelationId = 'CORR-' + Datetime.now().getTime() + '-' + Integer.valueOf(Math.random() * 10000);
        }
        return currentCorrelationId;
    }

    public static void setCorrelationId(String corrId) {
        currentCorrelationId = corrId;
    }

    public static void info(String sourceClass, String message, List<Id> recordIds) {
        log('Audit', sourceClass, 'Success', message, recordIds, null, null);
    }

    public static void warn(String sourceClass, String message, List<Id> recordIds, String nextAction) {
        log('Error', sourceClass, 'Retrying', message, recordIds, nextAction, null);
    }

    public static void error(String sourceClass, Exception ex, List<Id> recordIds, String nextAction) {
        String msg = ex != null ? ex.getMessage() + '\n' + ex.getStackTraceString() : 'Unknown error';
        log('Error', sourceClass, 'Failure', msg, recordIds, nextAction, null);
    }

    public static void log(String typeVal, String sourceClass, String statusVal, 
                           String message, List<Id> recordIds, String nextAction, Long durationMs) {
        try {
            Log__c entry = new Log__c();
            entry.Type__c = typeVal;
            entry.Class__c = sourceClass;
            entry.Status__c = statusVal;
            entry.Message__c = maskPii(message);
            entry.Correlation_Id__c = getCorrelationId();
            entry.Next_Action__c = nextAction;
            if (recordIds != null && !recordIds.isEmpty()) {
                entry.Record_Ids__c = String.join(recordIds, ',');
            }
            if (durationMs != null) {
                entry.Duration_Ms__c = durationMs;
            }
            Database.insert(entry, false, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'EevLogger failed to persist log: ' + e.getMessage());
        }
    }

    private static String maskPii(String input) {
        if (String.isBlank(input)) {
            return input;
        }
        // Mask emails like user@example.com -> u***@example.com
        return input.replaceAll('(?i)\\b([A-Za-z0-9._%+-])[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+\\.[A-Za-z]{2,})\\b', '$1***@$2');
    }
}

