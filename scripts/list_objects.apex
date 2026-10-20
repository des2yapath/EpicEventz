for (Schema.SObjectType t : Schema.getGlobalDescribe().values()) {
    String n = t.getDescribe().getName();
    if (n.endsWith('__c')) {
        System.debug('CUSTOM_OBJ: ' + n);
    }
}
