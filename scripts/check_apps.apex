for (AppMenuItem item : [SELECT Id, Name, Label, Type, IsVisible, ApplicationId FROM AppMenuItem WHERE Name LIKE '%Epic%' OR Label LIKE '%Epic%']) {
    System.debug('AppMenuItem: Name=' + item.Name + ', Label=' + item.Label + ', Type=' + item.Type + ', IsVisible=' + item.IsVisible);
}

Id userId = UserInfo.getUserId();
System.debug('Current User: ' + UserInfo.getUserName() + ', ProfileId: ' + UserInfo.getProfileId());

for (PermissionSetAssignment psa : [SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = :userId]) {
    System.debug('Assigned PS: ' + psa.PermissionSet.Name);
}

